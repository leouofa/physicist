# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      def index
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        target_type = params[:target_type].to_s.downcase.presence || "all"
        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        subatomic_particles_scope = SubatomicParticle.includes(:particle_group)
        quantum_states_scope = QuantumState.includes(subatomic_particle: :particle_group)

        if (mode == "semantic" || mode == "auto") && (subatomic_particles_scope.where.not(embedding: nil).exists? || quantum_states_scope.where.not(embedding: nil).exists?)
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            particle_results = []
            if %w[all subatomic_particle subatomic_particles particle particles].include?(target_type)
              particle_results = subatomic_particles_scope.where.not(embedding: nil)
                                                         .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                                         .limit(limit)
                                                         .map do |particle|
                                                           {
                                                             type: "SubatomicParticle",
                                                             score: 1.0 - particle.try(:neighbor_distance).to_f,
                                                             data: Serializer.subatomic_particle(particle, neighbor_distance: particle.try(:neighbor_distance))
                                                           }
                                                         end
            end

            quantum_state_results = []
            if %w[all quantum_state quantum_states state states].include?(target_type)
              quantum_state_results = quantum_states_scope.where.not(embedding: nil)
                                                          .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                                          .limit(limit)
                                                          .map do |qs|
                                                            {
                                                              type: "QuantumState",
                                                              score: 1.0 - qs.try(:neighbor_distance).to_f,
                                                              data: Serializer.quantum_state(qs, neighbor_distance: qs.try(:neighbor_distance))
                                                            }
                                                          end
            end

            combined = (particle_results + quantum_state_results).sort_by { |item| -item[:score] }.take(limit)
            return render_success(combined, meta: { mode: "semantic", query: query, count: combined.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        # Keyword fallback
        particle_kw = []
        if %w[all subatomic_particle subatomic_particles particle particles].include?(target_type)
          particle_kw = subatomic_particles_scope.where("subatomic_particles.name ILIKE :q OR subatomic_particles.description ILIKE :q", q: "%#{query}%")
                                                 .limit(limit)
                                                 .map { |p| { type: "SubatomicParticle", data: Serializer.subatomic_particle(p) } }
        end

        quantum_state_kw = []
        if %w[all quantum_state quantum_states state states].include?(target_type)
          quantum_state_kw = quantum_states_scope.joins(:subatomic_particle)
                                                 .where("quantum_states.name ILIKE :q OR quantum_states.description ILIKE :q OR subatomic_particles.name ILIKE :q", q: "%#{query}%")
                                                 .limit(limit)
                                                 .map { |qs| { type: "QuantumState", data: Serializer.quantum_state(qs) } }
        end

        combined = (particle_kw + quantum_state_kw).take(limit)
        render_success(combined, meta: { mode: "keyword", query: query, count: combined.size })
      end
    end
  end
end

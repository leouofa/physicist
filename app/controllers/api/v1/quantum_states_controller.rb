# frozen_string_literal: true

module Api
  module V1
    class QuantumStatesController < BaseController
      before_action :set_quantum_state, only: %i[show update destroy neighbors generate_embedding]

      def index
        scope = QuantumState.includes(subatomic_particle: :particle_group)
        scope = scope.where(subatomic_particle_id: params[:subatomic_particle_id]) if params[:subatomic_particle_id].present?
        if params[:particle_group_id].present?
          scope = scope.joins(:subatomic_particle).where(subatomic_particles: { particle_group_id: params[:particle_group_id] })
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(quantum_states.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.joins(:subatomic_particle).where("quantum_states.name ILIKE :q OR quantum_states.description ILIKE :q OR subatomic_particles.name ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("quantum_states.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        data = records.map do |b|
          Serializer.quantum_state(b, include_embedding: include_embedding, include_subatomic_particle: true)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = QuantumState.includes(subatomic_particle: :particle_group)
        scope = scope.where(subatomic_particle_id: params[:subatomic_particle_id]) if params[:subatomic_particle_id].present?
        if params[:particle_group_id].present?
          scope = scope.joins(:subatomic_particle).where(subatomic_particles: { particle_group_id: params[:particle_group_id] })
        end

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |quantum_state|
              dist = quantum_state.try(:neighbor_distance)
              Serializer.quantum_state(quantum_state, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.joins(:subatomic_particle)
                               .where("quantum_states.name ILIKE :q OR quantum_states.description ILIKE :q OR subatomic_particles.name ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |b| Serializer.quantum_state(b) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.quantum_state(@quantum_state, include_embedding: boolean_param(:include_embedding, default: false), include_subatomic_particle: true)
        )
      end

      def create
        particle = SubatomicParticle.find(params.require(:quantum_state).require(:subatomic_particle_id))
        quantum_state = particle.quantum_states.create!(quantum_state_params)
        render_success(Serializer.quantum_state(quantum_state), status: :created)
      end

      def update
        @quantum_state.update!(quantum_state_params)
        render_success(Serializer.quantum_state(@quantum_state))
      end

      def destroy
        @quantum_state.destroy!
        render_success({ id: @quantum_state.id, subatomic_particle_id: @quantum_state.subatomic_particle_id, deleted: true })
      end

      def neighbors
        unless @quantum_state.embedded?
          return render_error(code: "not_embedded", message: "Quantum state has no embedding generated yet", status: :unprocessable_entity)
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 50)
        cross_particle_only = boolean_param(:cross_particle_only, default: false)

        scope = @quantum_state.nearest_neighbors(:embedding, distance: "cosine")
        scope = scope.where.not(subatomic_particle_id: @quantum_state.subatomic_particle_id) if cross_particle_only

        neighbors = scope.limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.quantum_state(neighbor, neighbor_distance: neighbor.neighbor_distance)
        end

        render_success(
          results,
          meta: {
            source_id: @quantum_state.id,
            source_name: @quantum_state.name,
            subatomic_particle_id: @quantum_state.subatomic_particle_id,
            cross_particle_only: cross_particle_only,
            count: results.size
          }
        )
      end

      def generate_embedding
        if sync_requested?
          result = @quantum_state.generate_embedding!
          render_success(
            Serializer.quantum_state(@quantum_state, include_embedding: true),
            meta: { embedding_model: result[:model], dimensions: result[:dimensions] }
          )
        else
          job = GenerateEmbeddingJob.perform_later("QuantumState", @quantum_state.id)
          render_success({ job_id: job.job_id, status: "queued", id: @quantum_state.id }, status: :accepted)
        end
      end

      def populate
        subatomic_particle_id = params[:subatomic_particle_id].presence

        if sync_requested?
          result = PopulateQuantumStatesJob.new.perform(subatomic_particle_id: subatomic_particle_id)
          render_success({ message: "Quantum states populated", result: result })
        else
          job = PopulateQuantumStatesJob.perform_later(subatomic_particle_id: subatomic_particle_id)
          render_success({ job_id: job.job_id, status: "queued", subatomic_particle_id: subatomic_particle_id }, status: :accepted)
        end
      end

      def upsert_batch
        subatomic_particle = SubatomicParticle.find(params[:subatomic_particle_id])
        entries = params.require(:quantum_states).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = QuantumState.upsert_batch!(subatomic_particle, entries)
        render_success(
          upserted.map { |b| Serializer.quantum_state(b) },
          meta: { count: upserted.size, subatomic_particle_id: subatomic_particle.id }
        )
      end

      private

      def set_quantum_state
        @quantum_state = QuantumState.find(params[:id])
      end

      def quantum_state_params
        params.require(:quantum_state).permit(:subatomic_particle_id, :name, :description, themes: [])
      end
    end
  end
end

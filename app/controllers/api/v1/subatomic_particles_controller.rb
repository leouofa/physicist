# frozen_string_literal: true

module Api
  module V1
    class SubatomicParticlesController < BaseController
      before_action :set_subatomic_particle, only: %i[show update destroy neighbors generate_embedding populate_quantum_states]

      def index
        scope = SubatomicParticle.includes(:particle_group)
        scope = scope.where(particle_group_id: params[:particle_group_id]) if params[:particle_group_id].present?
        if params[:particle_group].present?
          scope = scope.joins(:particle_group).where("particle_groups.name ILIKE ?", "%#{params[:particle_group]}%")
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(subatomic_particles.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.where("subatomic_particles.name ILIKE :q OR subatomic_particles.description ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("subatomic_particles.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        include_quantum_states = boolean_param(:include_quantum_states, default: false)

        data = records.map do |s|
          Serializer.subatomic_particle(s, include_embedding: include_embedding, include_quantum_states: include_quantum_states)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = SubatomicParticle.includes(:particle_group)
        scope = scope.where(particle_group_id: params[:particle_group_id]) if params[:particle_group_id].present?

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |particle|
              dist = particle.try(:neighbor_distance)
              Serializer.subatomic_particle(particle, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.where("subatomic_particles.name ILIKE :q OR subatomic_particles.description ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |particle| Serializer.subatomic_particle(particle) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.subatomic_particle(
            @subatomic_particle,
            include_embedding: boolean_param(:include_embedding, default: false),
            include_quantum_states: boolean_param(:include_quantum_states, default: true)
          )
        )
      end

      def create
        particle = SubatomicParticle.create!(subatomic_particle_params)
        render_success(Serializer.subatomic_particle(particle), status: :created)
      end

      def update
        @subatomic_particle.update!(subatomic_particle_params)
        render_success(Serializer.subatomic_particle(@subatomic_particle))
      end

      def destroy
        @subatomic_particle.destroy!
        render_success({ id: @subatomic_particle.id, name: @subatomic_particle.name, deleted: true })
      end

      def neighbors
        unless @subatomic_particle.embedded?
          return render_error(code: "not_embedded", message: "Subatomic particle has no embedding generated yet", status: :unprocessable_entity)
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 50)
        cross_group_only = boolean_param(:cross_group_only, default: false)

        scope = @subatomic_particle.nearest_neighbors(:embedding, distance: "cosine")
        scope = scope.where.not(particle_group_id: @subatomic_particle.particle_group_id) if cross_group_only

        neighbors = scope.limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.subatomic_particle(neighbor, neighbor_distance: neighbor.neighbor_distance)
        end

        render_success(
          results,
          meta: {
            source_id: @subatomic_particle.id,
            source_name: @subatomic_particle.name,
            particle_group_id: @subatomic_particle.particle_group_id,
            cross_group_only: cross_group_only,
            count: results.size
          }
        )
      end

      def generate_embedding
        if sync_requested?
          result = @subatomic_particle.generate_embedding!
          render_success(
            Serializer.subatomic_particle(@subatomic_particle, include_embedding: true),
            meta: { embedding_model: result[:model], dimensions: result[:dimensions] }
          )
        else
          job = GenerateEmbeddingJob.perform_later("SubatomicParticle", @subatomic_particle.id)
          render_success({ job_id: job.job_id, status: "queued", id: @subatomic_particle.id }, status: :accepted)
        end
      end

      def populate_quantum_states
        if sync_requested?
          result = PopulateQuantumStatesJob.new.perform(subatomic_particle_id: @subatomic_particle.id)
          render_success({ message: "Quantum states populated for #{@subatomic_particle.name}", result: result })
        else
          job = PopulateQuantumStatesJob.perform_later(subatomic_particle_id: @subatomic_particle.id)
          render_success({ job_id: job.job_id, status: "queued", subatomic_particle_id: @subatomic_particle.id }, status: :accepted)
        end
      end

      def populate
        particle_group_id = params[:particle_group_id].presence

        if sync_requested?
          result = PopulateSubatomicParticlesJob.new.perform(particle_group_id: particle_group_id)
          render_success({ message: "Subatomic particles populated", result: result })
        else
          job = PopulateSubatomicParticlesJob.perform_later(particle_group_id: particle_group_id)
          render_success({ job_id: job.job_id, status: "queued", particle_group_id: particle_group_id }, status: :accepted)
        end
      end

      def upsert_batch
        particle_group = ParticleGroup.find(params[:particle_group_id])
        entries = params.require(:subatomic_particles).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = SubatomicParticle.upsert_batch!(particle_group, entries)
        render_success(
          upserted.map { |s| Serializer.subatomic_particle(s) },
          meta: { count: upserted.size, particle_group_id: particle_group.id }
        )
      end

      private

      def set_subatomic_particle
        @subatomic_particle = SubatomicParticle.find(params[:id])
      end

      def subatomic_particle_params
        params.require(:subatomic_particle).permit(:particle_group_id, :name, :description, themes: [])
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class ParticleGroupsController < BaseController
      before_action :set_particle_group, only: %i[show update destroy populate_subatomic_particles]

      def index
        scope = ParticleGroup.all
        scope = scope.where("name ILIKE :q OR description ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

        records, meta = paginate(scope.order("name ASC"))
        include_subatomic_particles = boolean_param(:include_subatomic_particles, default: false)

        data = records.map do |c|
          Serializer.particle_group(c, include_subatomic_particles: include_subatomic_particles)
        end

        render_success(data, meta: meta)
      end

      def show
        render_success(
          Serializer.particle_group(@particle_group, include_subatomic_particles: boolean_param(:include_subatomic_particles, default: true))
        )
      end

      def create
        particle_group = ParticleGroup.create!(particle_group_params)
        render_success(Serializer.particle_group(particle_group), status: :created)
      end

      def update
        @particle_group.update!(particle_group_params)
        render_success(Serializer.particle_group(@particle_group))
      end

      def destroy
        @particle_group.destroy!
        render_success({ id: @particle_group.id, name: @particle_group.name, deleted: true })
      end

      def populate_subatomic_particles
        if sync_requested?
          result = PopulateSubatomicParticlesJob.new.perform(particle_group_id: @particle_group.id)
          render_success({ message: "Subatomic particles populated for #{@particle_group.name}", result: result })
        else
          job = PopulateSubatomicParticlesJob.perform_later(particle_group_id: @particle_group.id)
          render_success({ job_id: job.job_id, status: "queued", particle_group_id: @particle_group.id }, status: :accepted)
        end
      end

      def populate
        if sync_requested?
          result = PopulateParticleGroupsJob.new.perform
          render_success({ message: "Particle groups populated", result: result })
        else
          job = PopulateParticleGroupsJob.perform_later
          render_success({ job_id: job.job_id, status: "queued" }, status: :accepted)
        end
      end

      def upsert_batch
        entries = params.require(:particle_groups).map do |entry|
          entry.permit(:name, :description).to_h
        end
        upserted = ParticleGroup.upsert_batch!(entries)
        render_success(
          upserted.map { |c| Serializer.particle_group(c) },
          meta: { count: upserted.size }
        )
      end

      private

      def set_particle_group
        @particle_group = ParticleGroup.find(params[:id])
      end

      def particle_group_params
        params.require(:particle_group).permit(:name, :description)
      end
    end
  end
end

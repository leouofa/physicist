# frozen_string_literal: true

class SubatomicParticlesController < ApplicationController
  include EmbeddableActions

  def show
    @subatomic_particle = SubatomicParticle.includes(:particle_group, :quantum_states).find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "cluster_modal",
          partial: "subatomic_particles/modal",
          locals: { subatomic_particle: @subatomic_particle }
        )
      end
    end
  end

  def generate_embedding
    @subatomic_particle = SubatomicParticle.find(params[:id])
    enqueue_embedding_generation(@subatomic_particle)
  end

  def populate
    PopulateSubatomicParticlesJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_all_subatomic_particles_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_all_subatomic_particles_controls",
            action_path: populate_subatomic_particles_path,
            idle_label: "Discover Subatomic Particles",
            running_label: "Discovering Subatomic Particles...",
            running: true,
            status_message: "Discovering subatomic particles across particle groups with LLM...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to subatomic_particles_path, notice: "Discovering subatomic particles across particle groups with LLM..." }
    end
  end

  def populate_quantum_states
    @subatomic_particle = SubatomicParticle.find(params[:id])
    PopulateQuantumStatesJob.perform_later(subatomic_particle_id: @subatomic_particle.id)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Discovering quantum states for #{@subatomic_particle.name}..."
        render turbo_stream: turbo_stream.replace(
          "subatomic_particle_quantum_states_section",
          partial: "subatomic_particles/quantum_states_section",
          locals: { subatomic_particle: @subatomic_particle, status_message: flash.now[:notice], status_kind: :info }
        )
      end
      format.html { redirect_to subatomic_particle_path(@subatomic_particle), notice: "Discovering quantum states for #{@subatomic_particle.name}..." }
    end
  end

  private

  def find_embeddable_record
    SubatomicParticle.find(params[:id])
  end
end

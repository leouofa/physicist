# frozen_string_literal: true

class QuantumStatesController < ApplicationController
  include EmbeddableActions

  def show
    @quantum_state = QuantumState.includes(subatomic_particle: :particle_group).find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "cluster_modal",
          partial: "quantum_states/modal",
          locals: { quantum_state: @quantum_state }
        )
      end
    end
  end

  def generate_embedding
    @quantum_state = QuantumState.find(params[:id])
    enqueue_embedding_generation(@quantum_state)
  end

  def populate
    PopulateQuantumStatesJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_all_quantum_states_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_all_quantum_states_controls",
            action_path: populate_quantum_states_path,
            idle_label: "Discover Quantum States",
            running_label: "Discovering Quantum States...",
            running: true,
            status_message: "Discovering quantum states across subatomic particles with LLM...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to quantum_states_path, notice: "Discovering quantum states across subatomic particles with LLM..." }
    end
  end

  private

  def find_embeddable_record
    QuantumState.find(params[:id])
  end
end

# frozen_string_literal: true

class ParticleGroupsController < ApplicationController
  def populate
    PopulateParticleGroupsJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_controls",
            action_path: populate_particle_groups_path,
            idle_label: "Populate Particle Groups",
            running_label: "Discovering Particle Groups...",
            running: true,
            status_message: "Discovering major particle groups with LLM...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to root_path, notice: "Particle group discovery queued." }
    end
  end
end

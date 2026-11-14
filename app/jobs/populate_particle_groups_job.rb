# frozen_string_literal: true

class PopulateParticleGroupsJob < ApplicationJob
  queue_as :default

  STREAM_NAME = "populate_particle_groups"
  DISCOVERY_PROMPT = "Identify major particle groups across the Standard Model (Quarks, Leptons, Gauge Bosons, Scalar Bosons), composite hadrons (Baryons, Mesons, Exotic Hadrons), condensed-matter quasiparticles (Phonons, Cooper Pairs, Anyons), and notable BSM/hypothetical sectors and return their canonical names and descriptions as JSON."

  def perform
    Llm::ModelRegistry.ensure_configured_model!

    existing_names = ParticleGroup.ordered.pluck(:name)
    chat = ParticleGroupDiscoveryAgent.create!(existing_names: existing_names)
    response = chat.ask(DISCOVERY_PROMPT)

    entries = Llm::JsonResponseParser.extract_list(response, key: "particle_groups")
    upserted = ParticleGroup.upsert_batch!(entries)
    raise "LLM response did not contain any valid particle groups." if upserted.empty?

    message = "Upserted #{upserted.size} #{'particle group'.pluralize(upserted.size)} (#{ParticleGroup.count} total)."
    track_completed(message: message, result: { upserted_count: upserted.size, total_count: ParticleGroup.count })

    broadcast_state(
      status_message: message,
      status_kind: :success,
      running: false
    )
    { upserted_count: upserted.size, total_count: ParticleGroup.count }
  rescue StandardError => e
    Rails.logger.error("[PopulateParticleGroupsJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate particle groups: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate particle groups: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def broadcast_state(status_message:, status_kind:, running:)
    particle_groups = ParticleGroup.ordered.to_a

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_controls",
        action_path: Rails.application.routes.url_helpers.populate_particle_groups_path,
        idle_label: "Populate Particle Groups",
        running_label: "Discovering Particle Groups...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "particle_groups_list",
      partial: "pages/particle_groups_list",
      locals: { particle_groups: particle_groups }
    )
  end
end

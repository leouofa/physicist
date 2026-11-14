# frozen_string_literal: true

class PopulateQuantumStatesJob < ApplicationJob
  STREAM_NAME = "quantum_states"
  GLOBAL_STREAM_NAME = STREAM_NAME

  queue_as :default
  sidekiq_options retry: 0

  def perform(subatomic_particle_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    subatomic_particles = if subatomic_particle_id.present?
                            SubatomicParticle.where(id: subatomic_particle_id).includes(:particle_group).to_a
    else
                            SubatomicParticle.includes(:particle_group).joins(:particle_group).order("particle_groups.name ASC, subatomic_particles.name ASC").to_a
    end

    if subatomic_particles.empty?
      msg = subatomic_particle_id.present? ? "Subatomic particle with ID #{subatomic_particle_id} not found." : "No subatomic particles found. Populate subatomic particles first before discovering quantum states."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_particles: [] }
    end

    total_upserted, failed_particles = populate_across_particles(subatomic_particles)
    summary = build_summary(total_upserted: total_upserted, total_particles: subatomic_particles.size, failed_particles: failed_particles)

    if failed_particles.size == subatomic_particles.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_quantum_states: QuantumState.count, failed_particles: failed_particles }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_particles: failed_particles }
  rescue StandardError => e
    Rails.logger.error("[PopulateQuantumStatesJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate quantum states: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate quantum states: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  def populate_subatomic_particle!(subatomic_particle)
    existing_names = subatomic_particle.quantum_states.ordered.pluck(:name)
    chat = QuantumStateDiscoveryAgent.create!(
      subatomic_particle_name: subatomic_particle.name,
      subatomic_particle_description: subatomic_particle.description,
      subatomic_particle_themes: subatomic_particle.themes,
      particle_group_name: subatomic_particle.particle_group.name,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(subatomic_particle))

    entries = Llm::JsonResponseParser.extract_list(response, key: "quantum_states")
    upserted = QuantumState.upsert_batch!(subatomic_particle, entries)
    raise "LLM response did not contain any valid quantum states for #{subatomic_particle.name}." if upserted.empty?

    upserted.size
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def populate_across_particles(subatomic_particles)
    total_upserted = 0
    failed_particles = []

    subatomic_particles.each_with_index do |particle, index|
      msg = "Discovering quantum states for #{particle.name} (#{index + 1}/#{subatomic_particles.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: subatomic_particles.size, subatomic_particle: particle.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_subatomic_particle!(particle)
    rescue StandardError => e
      Rails.logger.error("[PopulateQuantumStatesJob] SubatomicParticle=#{particle.name} #{e.class}: #{e.message}")
      failed_particles << particle.name
    end

    [ total_upserted, failed_particles ]
  end

  def discovery_prompt_for(subatomic_particle)
    "Identify 6 to 10 major, physically prominent quantum states, eigenstates, spin/polarization projections, or configurations in #{subatomic_particle.name} (#{subatomic_particle.particle_group.name}) and return them as a JSON list with name, description, and thematic tags."
  end

  def build_summary(total_upserted:, total_particles:, failed_particles:)
    total_quantum_states = QuantumState.count
    if failed_particles.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'quantum state'.pluralize(total_upserted)} across #{total_particles} #{'subatomic particle'.pluralize(total_particles)} (#{total_quantum_states} total)."
      }
    elsif failed_particles.size == total_particles
      {
        kind: :error,
        message: "Failed to populate quantum states for all subatomic particles: #{failed_particles.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'quantum state'.pluralize(total_upserted)} (#{total_quantum_states} total). Failed subatomic particles: #{failed_particles.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    particle_groups = QuantumState.grouped_by_subatomic_particle
    total_quantum_states_count = QuantumState.count
    subatomic_particles_count = SubatomicParticle.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_all_quantum_states_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_all_quantum_states_controls",
        action_path: Rails.application.routes.url_helpers.populate_quantum_states_path,
        idle_label: "Discover Quantum States",
        running_label: "Discovering Quantum States...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "quantum_states_list",
      partial: "pages/quantum_states_list",
      locals: {
        grouped_quantum_states: particle_groups,
        particle_groups: particle_groups,
        total_quantum_states_count: total_quantum_states_count,
        subatomic_particles_count: subatomic_particles_count
      }
    )
  end
end

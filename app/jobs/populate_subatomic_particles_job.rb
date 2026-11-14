# frozen_string_literal: true

class PopulateSubatomicParticlesJob < ApplicationJob
  STREAM_NAME = "subatomic_particles"
  GLOBAL_STREAM_NAME = STREAM_NAME

  queue_as :default
  sidekiq_options retry: 0

  def perform(particle_group_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    particle_groups = if particle_group_id.present?
                        ParticleGroup.where(id: particle_group_id).to_a
                      else
                        ParticleGroup.ordered.to_a
                      end

    if particle_groups.empty?
      msg = particle_group_id.present? ? "Particle group with ID #{particle_group_id} not found." : "No particle groups found. Populate particle groups first before discovering subatomic particles."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_groups: [] }
    end

    total_upserted, failed_groups = populate_across_groups(particle_groups)
    summary = build_summary(total_upserted: total_upserted, total_groups: particle_groups.size, failed_groups: failed_groups)

    if failed_groups.size == particle_groups.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_subatomic_particles: SubatomicParticle.count, failed_groups: failed_groups }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_groups: failed_groups }
  rescue StandardError => e
    Rails.logger.error("[PopulateSubatomicParticlesJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate subatomic particles: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate subatomic particles: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  def populate_particle_group!(particle_group)
    existing_names = particle_group.subatomic_particles.ordered.pluck(:name)
    chat = SubatomicParticleDiscoveryAgent.create!(
      particle_group_name: particle_group.name,
      particle_group_description: particle_group.description,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(particle_group))

    entries = Llm::JsonResponseParser.extract_list(response, key: "subatomic_particles")
    upserted = SubatomicParticle.upsert_batch!(particle_group, entries)
    raise "LLM response did not contain any valid subatomic particles for #{particle_group.name}." if upserted.empty?

    upserted.size
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def populate_across_groups(particle_groups)
    total_upserted = 0
    failed_groups = []

    particle_groups.each_with_index do |pg, index|
      msg = "Discovering subatomic particles for #{pg.name} (#{index + 1}/#{particle_groups.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: particle_groups.size, particle_group: pg.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_particle_group!(pg)
    rescue StandardError => e
      Rails.logger.error("[PopulateSubatomicParticlesJob] ParticleGroup=#{pg.name} #{e.class}: #{e.message}")
      failed_groups << pg.name
    end

    [ total_upserted, failed_groups ]
  end

  def discovery_prompt_for(particle_group)
    "Find prominent, archetypal subatomic particles and quanta belonging to #{particle_group.name} and return their names, descriptions, and thematic tags as JSON."
  end

  def build_summary(total_upserted:, total_groups:, failed_groups:)
    total_particles = SubatomicParticle.count
    if failed_groups.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'subatomic particle'.pluralize(total_upserted)} across #{total_groups} #{'particle group'.pluralize(total_groups)} (#{total_particles} total)."
      }
    elsif failed_groups.size == total_groups
      {
        kind: :error,
        message: "Failed to populate subatomic particles for all particle groups: #{failed_groups.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'subatomic particle'.pluralize(total_upserted)} (#{total_particles} total). Failed particle groups: #{failed_groups.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    particle_group_groups = SubatomicParticle.grouped_by_particle_group
    total_particles_count = SubatomicParticle.count
    particle_groups_count = ParticleGroup.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_all_subatomic_particles_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_all_subatomic_particles_controls",
        action_path: Rails.application.routes.url_helpers.populate_subatomic_particles_path,
        idle_label: "Discover Subatomic Particles",
        running_label: "Discovering Subatomic Particles...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "subatomic_particles_list",
      partial: "pages/subatomic_particles_list",
      locals: {
        grouped_subatomic_particles: particle_group_groups,
        particle_group_groups: particle_group_groups,
        total_subatomic_particles_count: total_particles_count,
        particle_groups_count: particle_groups_count
      }
    )
  end
end

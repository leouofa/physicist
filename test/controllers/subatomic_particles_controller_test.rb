# frozen_string_literal: true

require "test_helper"

class SubatomicParticlesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateSubatomicParticlesJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateSubatomicParticlesJob) do
      post populate_subatomic_particles_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Subatomic Particles...", response.body
  end

  test "populate enqueues PopulateSubatomicParticlesJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateSubatomicParticlesJob) do
      post populate_subatomic_particles_url
    end

    assert_redirected_to subatomic_particles_url
  end

  test "show renders particle details and Generate Embedding button" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.", themes: [ "quark" ])

    get subatomic_particle_url(particle)

    assert_response :success
    assert_match "Up", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.", themes: [ "quark" ])

    get subatomic_particle_url(particle), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Up", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Subatomic Particle Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "SubatomicParticle", particle.id ]) do
      post generate_embedding_subatomic_particle_url(particle), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "SubatomicParticle", particle.id ]) do
      post generate_embedding_subatomic_particle_url(particle)
    end

    assert_redirected_to subatomic_particle_url(particle)
  end
end

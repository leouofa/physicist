# frozen_string_literal: true

require "test_helper"

class QuantumStatesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateQuantumStatesJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateQuantumStatesJob) do
      post populate_quantum_states_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Quantum States...", response.body
  end

  test "populate enqueues PopulateQuantumStatesJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateQuantumStatesJob) do
      post populate_quantum_states_url
    end

    assert_redirected_to quantum_states_url
  end

  test "show renders quantum_state details and Generate Embedding button" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")
    state = QuantumState.create!(subatomic_particle: particle, name: "Red Color Charge", description: "SU(3) color state.", themes: [ "color" ])

    get quantum_state_url(state)

    assert_response :success
    assert_match "Red Color Charge", response.body
    assert_match "Up", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")
    state = QuantumState.create!(subatomic_particle: particle, name: "Red Color Charge", description: "SU(3) color state.", themes: [ "color" ])

    get quantum_state_url(state), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Red Color Charge", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Quantum State Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")
    state = QuantumState.create!(subatomic_particle: particle, name: "Red Color Charge", description: "SU(3) color state.", themes: [ "color" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "QuantumState", state.id ]) do
      post generate_embedding_quantum_state_url(state), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")
    state = QuantumState.create!(subatomic_particle: particle, name: "Red Color Charge", description: "SU(3) color state.", themes: [ "color" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "QuantumState", state.id ]) do
      post generate_embedding_quantum_state_url(state)
    end

    assert_redirected_to quantum_state_url(state)
  end
end

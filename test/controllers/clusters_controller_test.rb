# frozen_string_literal: true

require "test_helper"

class ClustersControllerTest < ActionDispatch::IntegrationTest
  test "GET /clusters returns success for subatomic_particles" do
    get clusters_path
    assert_response :success
    assert_select "h1", "Embedding Clusters"
    assert_select "input#similarity_level[value='5']"
  end

  test "GET /clusters with tab=quantum_states returns success" do
    get clusters_path(tab: "quantum_states", level: 3)
    assert_response :success
    assert_select "h1", "Embedding Clusters"
  end

  test "GET /clusters with turbo_stream format returns frame stream" do
    get clusters_path(tab: "subatomic_particles", level: 4), as: :turbo_stream
    assert_response :success
    assert_includes response.body, %(turbo-stream action="update" target="clusters_content_frame")
  end

  test "GET /clusters with level=15 renders complete coverage without singletons" do
    get clusters_path(level: 15)
    assert_response :success
    assert_select "span", text: /100% Clustered/
  end

  test "GET /clusters with full_coverage=true returns complete coverage" do
    get clusters_path(level: 6, full_coverage: "true")
    assert_response :success
    assert_select "span", text: /100% Clustered/
  end

  test "GET /clusters renders entity links targeting cluster_modal frame" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    v = Array.new(1024, 0.1)
    SubatomicParticle.create!(particle_group: group, name: "Up Modal Test", description: "Up quark", embedding: v)
    SubatomicParticle.create!(particle_group: group, name: "Down Modal Test", description: "Down quark", embedding: v)

    get clusters_path(tab: "subatomic_particles", level: 5)
    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_select "a[data-turbo-frame='cluster_modal']", text: "Up Modal Test"
    assert_select "a[data-turbo-frame='cluster_modal']", text: "View details →"
  end

  test "GET /clusters with quantum_states tab renders quantum_state links targeting cluster_modal frame" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Up quark")
    v = Array.new(1024, 0.1)
    QuantumState.create!(subatomic_particle: particle, name: "Red Color Modal Test", description: "Color state", themes: [ "color" ], embedding: v)
    QuantumState.create!(subatomic_particle: particle, name: "Blue Color Modal Test", description: "Color state", themes: [ "color" ], embedding: v)

    get clusters_path(tab: "quantum_states", level: 5)
    assert_response :success
    assert_select "a[data-turbo-frame='cluster_modal']", text: "Red Color Modal Test"
    assert_select "a[data-turbo-frame='cluster_modal']", text: "View details →"
  end

  test "POST /clusters/snapshot creates snapshot and redirects to it" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    v = Array.new(1024, 0.2)
    SubatomicParticle.create!(particle_group: group, name: "Snap Particle 1", description: "D1", themes: [ "quark" ], embedding: v)
    SubatomicParticle.create!(particle_group: group, name: "Snap Particle 2", description: "D2", themes: [ "quark" ], embedding: v)

    assert_difference "ClusterSnapshot.count", 1 do
      post snapshot_clusters_path, params: { tab: "subatomic_particles", level: 5, title: "Test Controller Snapshot" }
    end

    snapshot = ClusterSnapshot.last
    assert_equal "Test Controller Snapshot", snapshot.title
    assert_redirected_to cluster_snapshot_path(snapshot)
    follow_redirect!
    assert_response :success
  end
end

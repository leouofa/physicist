# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders empty state and populate button when no particle_groups exist" do
    get root_url

    assert_response :success
    assert_select "h1", "Particle Groups"
    assert_select "button", /Discover|Populate/
    assert_match "No particle groups yet", response.body
  end

  test "home lists all particle_groups ordered by name" do
    ParticleGroup.create!(name: "Leptons", description: "Elementary particles of spin 1/2.")
    ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")

    get root_url

    assert_response :success
    assert_select "article h2", count: 2
    assert_operator response.body.index("Leptons"), :<, response.body.index("Quarks")
    assert_match "Elementary particles of spin 1/2.", response.body
    assert_match "Fundamental elementary particles.", response.body
  end

  test "subatomic_particles renders empty state and populate button when no subatomic_particles exist" do
    get subatomic_particles_url

    assert_response :success
    assert_select "h1", "Subatomic Particles"
    assert_select "button", /Discover Subatomic Particles/
    assert_match "No subatomic particles yet", response.body
  end

  test "subatomic_particles lists all subatomic_particles in a table grouped by particle_group headers with themes" do
    leptons = ParticleGroup.create!(name: "Leptons", description: "Elementary particles of spin 1/2.")
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")

    SubatomicParticle.create!(particle_group: leptons, name: "Electron", description: "Lightest charged lepton.", themes: [ "lepton", "stable" ])
    SubatomicParticle.create!(particle_group: quarks, name: "Up", description: "Lightest quark.", themes: [ "quark", "fractional charge" ])
    SubatomicParticle.create!(particle_group: quarks, name: "Down", description: "Second lightest quark.", themes: [ "quark", "isospin" ])

    get subatomic_particles_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Leptons/
    assert_select "table tbody tr th", /Quarks/
    assert_operator response.body.index("Leptons"), :<, response.body.index("Quarks")
    assert_match "Lightest charged lepton.", response.body
    assert_match "fractional charge", response.body
    assert_match "lepton", response.body
    assert_match "stable", response.body
  end

  test "quantum_states renders empty state, populate button, and top navbar link when no quantum_states exist" do
    get quantum_states_url

    assert_response :success
    assert_select "nav a[href=?]", quantum_states_path, text: "Quantum States"
    assert_select "h1", "Quantum States"
    assert_select "button", /Discover Quantum States/
    assert_match "No quantum states yet", response.body
  end

  test "quantum_states lists all quantum_states in a table grouped by subatomic_particle headers" do
    leptons = ParticleGroup.create!(name: "Leptons", description: "Elementary particles of spin 1/2.")
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")

    electron = SubatomicParticle.create!(particle_group: leptons, name: "Electron", description: "Lightest charged lepton.")
    up = SubatomicParticle.create!(particle_group: quarks, name: "Up", description: "Lightest quark.")

    QuantumState.create!(subatomic_particle: electron, name: "Spin-Up", description: "Spin projection +1/2.", themes: [ "spin", "eigenstate" ])
    QuantumState.create!(subatomic_particle: electron, name: "Spin-Down", description: "Spin projection -1/2.", themes: [ "spin" ])
    QuantumState.create!(subatomic_particle: up, name: "Red Color Charge", description: "SU(3) color state.", themes: [ "color", "gauge" ])

    get quantum_states_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Electron/
    assert_select "table tbody tr th", /Up/
    assert_match "Spin-Up", response.body
    assert_match "Spin-Down", response.body
    assert_match "Red Color Charge", response.body
    assert_match "Spin projection +1/2.", response.body
  end
end

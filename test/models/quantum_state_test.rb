# frozen_string_literal: true

require "test_helper"

class QuantumStateTest < ActiveSupport::TestCase
  test "validates presence of name, description, and subatomic_particle" do
    state = QuantumState.new(name: " ", description: " ")
    assert_not state.valid?
    assert_includes state.errors[:subatomic_particle], "must exist"
    assert_includes state.errors[:name], "can't be blank"
    assert_includes state.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up Quark", description: "Lightest quark.")
    state = QuantumState.create!(
      subatomic_particle: particle,
      name: "  Spin-Up State   ",
      description: "  Projection +1/2 along quantization axis.  ",
      themes: [ " spin ", "Fermion", "SPIN", "", nil ]
    )

    assert_equal "Spin-Up State", state.name
    assert_equal "Projection +1/2 along quantization axis.", state.description
    assert_equal [ "spin", "Fermion" ], state.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    group = ParticleGroup.create!(name: "Leptons", description: "Elementary particles of spin 1/2.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Electron", description: "Lightest charged lepton.")
    state = QuantumState.create!(
      subatomic_particle: particle,
      name: "Ground State Orbital",
      description: "Lowest energy eigenvalue.",
      themes: "bound state, ground state, stable, Bound State"
    )

    assert_equal [ "bound state", "ground state", "stable" ], state.themes
  end

  test "enforces case-insensitive uniqueness scoped per subatomic_particle" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    quark_u = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")
    quark_d = SubatomicParticle.create!(particle_group: group, name: "Down", description: "Down quark.")

    QuantumState.create!(subatomic_particle: quark_u, name: "Red Color Charge", description: "SU(3) color state.")

    same_particle_dup = QuantumState.new(subatomic_particle: quark_u, name: "red color charge", description: "Duplicate.")
    assert_not same_particle_dup.valid?
    assert_includes same_particle_dup.errors[:name], "has already been taken"

    other_particle_state = QuantumState.new(subatomic_particle: quark_d, name: "Red Color Charge", description: "Down quark red color state.")
    assert other_particle_state.valid?
  end

  test "upsert_batch! inserts new quantum_states and updates existing ones within a subatomic_particle" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    quark_u = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")
    quark_d = SubatomicParticle.create!(particle_group: group, name: "Down", description: "Down quark.")

    QuantumState.create!(subatomic_particle: quark_u, name: "Red Color Charge", description: "Old description", themes: [ "color" ])
    QuantumState.create!(subatomic_particle: quark_d, name: "Red Color Charge", description: "Different particle state", themes: [ "color" ])

    results = QuantumState.upsert_batch!(quark_u, [
      { "name" => "  red color charge ", "description" => "SU(3) color charge eigenstate.", "themes" => [ "color", "gauge" ] },
      { "name" => "Blue Color Charge", "description" => "SU(3) blue eigenstate.", "themes" => [ "color", "su3" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Green Color Charge", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, quark_u.quantum_states.count
    assert_equal 1, quark_d.quantum_states.count

    red = quark_u.quantum_states.find_by!("LOWER(name) = ?", "red color charge")
    assert_equal "red color charge", red.name
    assert_equal "SU(3) color charge eigenstate.", red.description
    assert_equal [ "color", "gauge" ], red.themes

    blue = quark_u.quantum_states.find_by!(name: "Blue Color Charge")
    assert_equal [ "color", "su3" ], blue.themes
  end

  test "grouped_by_subatomic_particle returns particle groups and quantum_states sorted alphabetically" do
    leptons = ParticleGroup.create!(name: "Leptons", description: "Elementary leptons.")
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental quarks.")

    electron = SubatomicParticle.create!(particle_group: leptons, name: "Electron", description: "Lepton.")
    up = SubatomicParticle.create!(particle_group: quarks, name: "Up", description: "Quark.")

    QuantumState.create!(subatomic_particle: electron, name: "Spin-Up", description: "Spin projection.", themes: [ "spin" ])
    QuantumState.create!(subatomic_particle: electron, name: "Spin-Down", description: "Spin projection.", themes: [ "spin" ])
    QuantumState.create!(subatomic_particle: up, name: "Red Color", description: "Color state.", themes: [ "color" ])
    QuantumState.create!(subatomic_particle: up, name: "Blue Color", description: "Color state.", themes: [ "color" ])

    groups = QuantumState.grouped_by_subatomic_particle
    assert_equal [ "Electron", "Up" ], groups.map { |particle, _| particle.name }
    assert_equal [ "Spin-Down", "Spin-Up" ], groups[0][1].map(&:name)
    assert_equal [ "Blue Color", "Red Color" ], groups[1][1].map(&:name)
  end

  test "destroying a subatomic_particle destroys its associated quantum_states" do
    group = ParticleGroup.create!(name: "Quarks", description: "Quarks.")
    up = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Quark.")
    QuantumState.create!(subatomic_particle: up, name: "Red Color", description: "Color.", themes: [ "color" ])

    assert_difference "QuantumState.count", -1 do
      up.destroy
    end
  end

  test "embedding_input formats quantum_state, subatomic_particle, particle_group, description, and themes" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up Quark", description: "Lightest quark.")
    state = QuantumState.new(
      subatomic_particle: particle,
      name: "Spin-Up State",
      description: "Projection +1/2 along quantization axis.",
      themes: [ "spin", "eigenstate" ]
    )

    expected = <<~TXT.strip
      Quantum State / Eigenstate: Spin-Up State (Up Quark, Quarks)
      Description: Projection +1/2 along quantization axis.
      Themes: spin, eigenstate
    TXT

    assert_equal expected, state.embedding_input
  end
end

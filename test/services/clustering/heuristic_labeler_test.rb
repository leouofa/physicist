# frozen_string_literal: true

require "test_helper"

class HeuristicLabelerTest < ActiveSupport::TestCase
  test "labels an empty list of records" do
    result = Clustering::HeuristicLabeler.label([])
    assert_equal "Empty Cluster", result[:title]
    assert_empty result[:shared_themes]
  end

  test "extracts shared themes and builds archetype title for subatomic_particles" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    c1 = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Up quark", themes: %w[fermion fractional charge])
    c2 = SubatomicParticle.create!(particle_group: group, name: "Charm", description: "Charm quark", themes: %w[fermion fractional charge])

    result = Clustering::HeuristicLabeler.label([ c1, c2 ])
    assert_includes result[:shared_themes], "Fermion"
    assert_includes result[:title], "Archetype"
  end

  test "extracts shared themes for quantum_states" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Up quark")
    state1 = QuantumState.create!(subatomic_particle: particle, name: "Red Color Charge", description: "SU(3) state", themes: [ "color", "eigenstate" ])
    state2 = QuantumState.create!(subatomic_particle: particle, name: "Blue Color Charge", description: "SU(3) state", themes: [ "color", "gauge" ])

    result = Clustering::HeuristicLabeler.label([ state1, state2 ])
    assert_includes result[:shared_themes], "Color"
    assert_includes result[:title], "Archetype"
  end
end

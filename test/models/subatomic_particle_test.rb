# frozen_string_literal: true

require "test_helper"

class SubatomicParticleTest < ActiveSupport::TestCase
  test "validates presence of name, description, and particle_group" do
    particle = SubatomicParticle.new(name: " ", description: " ")
    assert_not particle.valid?
    assert_includes particle.errors[:particle_group], "must exist"
    assert_includes particle.errors[:name], "can't be blank"
    assert_includes particle.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(
      particle_group: group,
      name: "  Up   Quark ",
      description: "  Lightest of all quarks.  ",
      themes: [ " fractional charge ", "First Generation", "FRACTIONAL CHARGE", "", nil ]
    )

    assert_equal "Up Quark", particle.name
    assert_equal "Lightest of all quarks.", particle.description
    assert_equal [ "fractional charge", "First Generation" ], particle.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    group = ParticleGroup.create!(name: "Leptons", description: "Elementary particles of spin 1/2.")
    particle = SubatomicParticle.create!(
      particle_group: group,
      name: "Electron",
      description: "Elementary particle with a negative elementary electric charge.",
      themes: "lepton, negative charge, stable, Lepton"
    )

    assert_equal [ "lepton", "negative charge", "stable" ], particle.themes
  end

  test "enforces case-insensitive uniqueness scoped per particle_group" do
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    leptons = ParticleGroup.create!(name: "Leptons", description: "Elementary particles of half-integer spin.")

    SubatomicParticle.create!(particle_group: quarks, name: "Up", description: "Lightest quark.")

    same_group_dup = SubatomicParticle.new(particle_group: quarks, name: "up", description: "Duplicate.")
    assert_not same_group_dup.valid?
    assert_includes same_group_dup.errors[:name], "has already been taken"

    other_group_particle = SubatomicParticle.new(particle_group: leptons, name: "Up", description: "Hypothetical lepton namesake.")
    assert other_group_particle.valid?
  end

  test "upsert_batch! inserts new subatomic_particles and updates existing ones within a particle_group" do
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    leptons = ParticleGroup.create!(name: "Leptons", description: "Elementary particles of spin 1/2.")

    SubatomicParticle.create!(particle_group: quarks, name: "Up", description: "Old description", themes: [ "first generation" ])
    SubatomicParticle.create!(particle_group: leptons, name: "Up", description: "Unrelated namesake", themes: [ "test" ])

    results = SubatomicParticle.upsert_batch!(quarks, [
      { "name" => "  up ", "description" => "Lightest of all quarks.", "themes" => [ "first generation", "fractional charge" ] },
      { "name" => "Down", "description" => "Second lightest quark.", "themes" => [ "first generation", "isospin down" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Charm", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, quarks.subatomic_particles.count
    assert_equal 1, leptons.subatomic_particles.count

    up = quarks.subatomic_particles.find_by!("LOWER(name) = ?", "up")
    assert_equal "up", up.name
    assert_equal "Lightest of all quarks.", up.description
    assert_equal [ "first generation", "fractional charge" ], up.themes

    down = quarks.subatomic_particles.find_by!(name: "Down")
    assert_equal [ "first generation", "isospin down" ], down.themes
  end

  test "grouped_by_particle_group returns particle_group groups and subatomic_particles sorted alphabetically" do
    leptons = ParticleGroup.create!(name: "Leptons", description: "Elementary particles of spin 1/2.")
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    ParticleGroup.create!(name: "Gauge Bosons", description: "Empty group.")

    SubatomicParticle.create!(particle_group: leptons, name: "Electron", description: "Lightest charged lepton.", themes: [ "lepton" ])
    SubatomicParticle.create!(particle_group: leptons, name: "Muon", description: "Second generation lepton.", themes: [ "lepton" ])
    SubatomicParticle.create!(particle_group: quarks, name: "Up Quark", description: "Lightest quark.", themes: [ "quark" ])
    SubatomicParticle.create!(particle_group: quarks, name: "Down Quark", description: "Second lightest quark.", themes: [ "quark" ])

    groups = SubatomicParticle.grouped_by_particle_group
    assert_equal [ "Leptons", "Quarks" ], groups.map { |group, _| group.name }
    assert_equal [ "Electron", "Muon" ], groups[0][1].map(&:name)
    assert_equal [ "Down Quark", "Up Quark" ], groups[1][1].map(&:name)
  end

  test "destroying a particle_group destroys its associated subatomic_particles" do
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    SubatomicParticle.create!(particle_group: quarks, name: "Up", description: "Lightest quark.", themes: [ "quark" ])

    assert_difference("SubatomicParticle.count", -1) do
      quarks.destroy!
    end
  end

  test "embedding_input formats particle_group, name, description, and themes" do
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: quarks, name: "Up Quark", description: "Lightest quark.", themes: [ "quark", "fractional charge" ])

    expected = <<~TEXT.chomp
      Subatomic Particle: Up Quark (Quarks)
      Description: Lightest quark.
      Themes: quark, fractional charge
    TEXT

    assert_equal expected, particle.embedding_input
    assert_not particle.embedded?
  end
end

# frozen_string_literal: true

require "test_helper"

class ParticleGroupTest < ActiveSupport::TestCase
  test "validates presence of name and description" do
    particle_group = ParticleGroup.new(name: " ", description: " ")
    assert_not particle_group.valid?
    assert_includes particle_group.errors[:name], "can't be blank"
    assert_includes particle_group.errors[:description], "can't be blank"
  end

  test "normalizes name whitespace and enforces case-insensitive uniqueness" do
    first = ParticleGroup.create!(name: "  Quarks   ", description: "Fundamental elementary particles.")
    assert_equal "Quarks", first.name

    duplicate = ParticleGroup.new(name: "quarks", description: "Duplicate.")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "upsert_batch! inserts new particle_groups and updates existing ones case-insensitively" do
    ParticleGroup.create!(name: "Quarks", description: "Old description")

    results = ParticleGroup.upsert_batch!([
      { "name" => "  quarks ", "description" => "Updated Quarks description." },
      { "name" => "Leptons", "description" => "Elementary particles of spin 1/2." },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Gauge Bosons", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, ParticleGroup.count

    quarks = ParticleGroup.find_by!("LOWER(name) = ?", "quarks")
    assert_equal "quarks", quarks.name
    assert_equal "Updated Quarks description.", quarks.description

    leptons = ParticleGroup.find_by!(name: "Leptons")
    assert_equal "Elementary particles of spin 1/2.", leptons.description
  end
end

# frozen_string_literal: true

require "test_helper"

class ClusterSnapshotTest < ActiveSupport::TestCase
  test "validates presence and inclusion" do
    snapshot = ClusterSnapshot.new
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:target_type], "can't be blank"
    assert_includes snapshot.errors[:level], "can't be blank"
    assert_includes snapshot.errors[:distance_threshold], "can't be blank"
    assert_includes snapshot.errors[:title], "can't be blank"

    snapshot.target_type = "Invalid"
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:target_type], "is not included in the list"

    snapshot.target_type = "SubatomicParticle"
    snapshot.level = 16
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:level], "is not included in the list"

    snapshot.level = 15
    snapshot.distance_threshold = 0.22
    snapshot.title = "Valid Title"
    assert snapshot.valid?
  end

  test "creates snapshot with groups and memberships and cascades destruction" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up Quark", description: "Lightest quark.", themes: [ "fermion", "fractional charge" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "SubatomicParticle",
      level: 5,
      distance_threshold: 0.22,
      title: "Test Snapshot",
      clusters_count: 1,
      items_count: 1
    )

    cluster_group = snapshot.cluster_groups.create!(
      name: "First Generation Quarks",
      shared_themes: [ "Fermion", "Fractional Charge" ],
      size: 1
    )

    membership = cluster_group.cluster_memberships.create!(
      record: particle
    )

    assert_equal 1, snapshot.cluster_groups.count
    assert_equal 1, snapshot.cluster_memberships.count
    assert_equal particle, cluster_group.cluster_memberships.first.record

    assert_difference("ClusterSnapshot.count", -1) do
      assert_difference("ClusterGroup.count", -1) do
        assert_difference("ClusterMembership.count", -1) do
          snapshot.destroy!
        end
      end
    end
  end
end

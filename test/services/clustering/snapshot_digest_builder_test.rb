# frozen_string_literal: true

require "test_helper"

class SnapshotDigestBuilderTest < ActiveSupport::TestCase
  test "builds digest for SubatomicParticle snapshot" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle1 = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.", themes: [ "quark", "fractional charge" ])
    particle2 = SubatomicParticle.create!(particle_group: group, name: "Down", description: "Down quark.", themes: [ "quark", "isospin" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "SubatomicParticle",
      level: 5,
      distance_threshold: 0.20,
      title: "Quark Families",
      clusters_count: 1,
      items_count: 2
    )

    cluster_group = snapshot.cluster_groups.create!(name: "First Gen Quarks", shared_themes: [ "quark", "first gen" ], size: 2)
    cluster_group.cluster_memberships.create!(record: particle1)
    cluster_group.cluster_memberships.create!(record: particle2)

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, max_chars: 10_000)

    assert_includes digest, "=== CLUSTER SNAPSHOT OVERVIEW ==="
    assert_includes digest, "Quark Families"
    assert_includes digest, "Target Type: SubatomicParticle"
    assert_includes digest, "First Gen Quarks"
    assert_includes digest, "Up (Quarks)"
    assert_includes digest, "Down (Quarks)"
  end

  test "builds digest for QuantumState snapshot" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Up quark.")
    state = QuantumState.create!(subatomic_particle: particle, name: "Red Color Charge", description: "SU(3) color eigenstate.", themes: [ "color", "gauge" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "QuantumState",
      level: 10,
      distance_threshold: 0.25,
      title: "QuantumState Clusters",
      clusters_count: 1,
      items_count: 1
    )

    cluster_group = snapshot.cluster_groups.create!(name: "Color Gauge Eigenstates", shared_themes: [ "color" ], size: 1)
    cluster_group.cluster_memberships.create!(record: state)

    report = snapshot.cluster_reports.create!(prompt: "Analyze color gauge eigenstates")
    report.cluster_report_summaries.create!(
      cluster_group: cluster_group,
      content: "This cluster focuses on SU(3) color gauge eigenstates.",
      position: 1
    )

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, report: report, max_chars: 5_000)

    assert_includes digest, "Target Type: QuantumState"
    assert_includes digest, "Red Color Charge (Up, Quarks)"
    assert_includes digest, "SU(3) color gauge eigenstates"
  end
end

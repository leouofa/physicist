# frozen_string_literal: true

require "test_helper"

class Api::V1::ParticleGroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @particle_group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
  end

  test "GET /api/v1/particle_groups returns list" do
    get api_v1_particle_groups_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert json["meta"].key?("total")
    names = json["data"].map { |p| p["name"] }
    assert_includes names, "Quarks"
  end

  test "GET /api/v1/particle_groups/:id returns single particle_group" do
    get api_v1_particle_group_url(@particle_group), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @particle_group.name, json.dig("data", "name")
  end

  test "POST /api/v1/particle_groups creates a new particle_group" do
    assert_difference("ParticleGroup.count", 1) do
      post api_v1_particle_groups_url, params: { particle_group: { name: "Leptons", description: "Elementary particles of spin 1/2." } }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal "Leptons", json.dig("data", "name")
  end

  test "PATCH /api/v1/particle_groups/:id updates a particle_group" do
    patch api_v1_particle_group_url(@particle_group), params: { particle_group: { description: "Updated description" } }, as: :json
    assert_response :success

    @particle_group.reload
    assert_equal "Updated description", @particle_group.description
  end

  test "DELETE /api/v1/particle_groups/:id removes a particle_group" do
    assert_difference("ParticleGroup.count", -1) do
      delete api_v1_particle_group_url(@particle_group), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "POST /api/v1/particle_groups/upsert_batch upserts multiple particle_groups" do
    payload = {
      particle_groups: [
        { name: "Quarks", description: "New Quarks description" },
        { name: "Gauge Bosons", description: "Force carrier particles." }
      ]
    }

    assert_difference("ParticleGroup.count", 1) do
      post upsert_batch_api_v1_particle_groups_url, params: payload, as: :json
    end
    assert_response :success

    assert_equal "New Quarks description", @particle_group.reload.description
    assert ParticleGroup.find_by(name: "Gauge Bosons")
  end

  test "POST /api/v1/particle_groups/populate enqueues PopulateParticleGroupsJob by default" do
    assert_enqueued_with(job: PopulateParticleGroupsJob) do
      post populate_api_v1_particle_groups_url, as: :json
    end
    assert_response :accepted
    assert response.parsed_body.dig("data", "job_id").present?
  end

  test "POST /api/v1/particle_groups/:id/populate_subatomic_particles enqueues PopulateSubatomicParticlesJob" do
    assert_enqueued_with(job: PopulateSubatomicParticlesJob, args: [ { particle_group_id: @particle_group.id } ]) do
      post populate_subatomic_particles_api_v1_particle_group_url(@particle_group), as: :json
    end
    assert_response :accepted
  end
end

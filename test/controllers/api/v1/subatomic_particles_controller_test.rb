# frozen_string_literal: true

require "test_helper"

class Api::V1::SubatomicParticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @particle_group = ParticleGroup.create!(name: "Quarks", description: "Quark particle group.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.99 : 0.01 }

    @subatomic_particle = SubatomicParticle.create!(
      particle_group: @particle_group,
      name: "Up",
      description: "Lightest quark constituent of protons.",
      themes: [ "quark", "first generation", "fractional charge" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/subatomic_particles returns list with filtering" do
    get api_v1_subatomic_particles_url, params: { particle_group_id: @particle_group.id, theme: "fractional charge" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Up", json["data"].first["name"]
    assert_equal false, json["data"].first.key?("embedding")
  end

  test "GET /api/v1/subatomic_particles/:id returns particle with particle_group details" do
    get api_v1_subatomic_particle_url(@subatomic_particle), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "Up", json.dig("data", "name")
    assert_equal "Quarks", json.dig("data", "particle_group", "name")
  end

  test "GET /api/v1/subatomic_particles/:id with include_embedding=true returns raw vector" do
    get api_v1_subatomic_particle_url(@subatomic_particle), params: { include_embedding: "true" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json.dig("data", "embedding").is_a?(Array)
    assert_equal 1024, json.dig("data", "embedding").size
  end

  test "POST /api/v1/subatomic_particles creates a particle" do
    assert_difference("SubatomicParticle.count", 1) do
      post api_v1_subatomic_particles_url, params: {
        subatomic_particle: {
          particle_group_id: @particle_group.id,
          name: "Down",
          description: "Second lightest quark.",
          themes: [ "quark", "isospin down" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Down", response.parsed_body.dig("data", "name")
  end

  test "PATCH /api/v1/subatomic_particles/:id updates particle" do
    patch api_v1_subatomic_particle_url(@subatomic_particle), params: { subatomic_particle: { description: "Updated Up description" } }, as: :json
    assert_response :success
    assert_equal "Updated Up description", @subatomic_particle.reload.description
  end

  test "DELETE /api/v1/subatomic_particles/:id deletes particle" do
    assert_difference("SubatomicParticle.count", -1) do
      delete api_v1_subatomic_particle_url(@subatomic_particle), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/subatomic_particles/:id/neighbors finds nearest particles" do
    other = SubatomicParticle.create!(
      particle_group: @particle_group,
      name: "Charm",
      description: "Second generation up-type quark.",
      themes: [ "quark", "second generation" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_subatomic_particle_url(@subatomic_particle), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "Charm", json["data"].first["name"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/subatomic_particles/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_subatomic_particle_url(@subatomic_particle), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end

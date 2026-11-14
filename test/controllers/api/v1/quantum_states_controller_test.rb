# frozen_string_literal: true

require "test_helper"

class Api::V1::QuantumStatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @particle_group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.98 : 0.02 }

    @subatomic_particle = SubatomicParticle.create!(particle_group: @particle_group, name: "Up", description: "Lightest quark.", themes: [ "quark" ])
    @other_subatomic_particle = SubatomicParticle.create!(particle_group: @particle_group, name: "Down", description: "Down quark.", themes: [ "quark" ])

    @quantum_state = QuantumState.create!(
      subatomic_particle: @subatomic_particle,
      name: "Red Color Charge",
      description: "SU(3) color charge eigenstate.",
      themes: [ "color", "gauge" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/quantum_states returns list" do
    get api_v1_quantum_states_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal 1, json["data"].size
    assert_equal "Red Color Charge", json["data"].first["name"]
    assert_equal "Up", json["data"].first.dig("subatomic_particle", "name")
  end

  test "GET /api/v1/quantum_states/:id returns quantum_state" do
    get api_v1_quantum_state_url(@quantum_state), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @quantum_state.id, json.dig("data", "id")
    assert_equal "Red Color Charge", json.dig("data", "name")
    assert_includes json.dig("data", "themes"), "color"
  end

  test "POST /api/v1/quantum_states creates quantum_state for a subatomic_particle" do
    assert_difference("QuantumState.count", 1) do
      post api_v1_quantum_states_url, params: {
        quantum_state: {
          subatomic_particle_id: @other_subatomic_particle.id,
          name: "Blue Color Charge",
          description: "SU(3) blue color eigenstate.",
          themes: [ "color", "eigenstate" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Blue Color Charge", response.parsed_body.dig("data", "name")
    assert_equal @other_subatomic_particle.id, response.parsed_body.dig("data", "subatomic_particle_id")
  end

  test "PATCH /api/v1/quantum_states/:id updates quantum_state" do
    patch api_v1_quantum_state_url(@quantum_state), params: {
      quantum_state: {
        description: "Updated Red Color Charge description."
      }
    }, as: :json
    assert_response :success
    assert_equal "Updated Red Color Charge description.", @quantum_state.reload.description
  end

  test "DELETE /api/v1/quantum_states/:id deletes quantum_state" do
    assert_difference("QuantumState.count", -1) do
      delete api_v1_quantum_state_url(@quantum_state), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/quantum_states/:id/neighbors finds nearest quantum_states" do
    other_quantum_state = QuantumState.create!(
      subatomic_particle: @subatomic_particle,
      name: "Blue Color Charge",
      description: "SU(3) blue color eigenstate.",
      themes: [ "color", "gauge" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_quantum_state_url(@quantum_state), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal other_quantum_state.id, json["data"].first["id"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/quantum_states/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_quantum_state_url(@quantum_state), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end

# frozen_string_literal: true

require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @particle_group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    @vector = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }

    @subatomic_particle = SubatomicParticle.create!(
      particle_group: @particle_group,
      name: "Up",
      description: "Lightest quark constituent of matter.",
      themes: [ "quark", "first generation", "fractional charge" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    @quantum_state = QuantumState.create!(
      subatomic_particle: @subatomic_particle,
      name: "Red Color Charge",
      description: "SU(3) color gauge eigenstate.",
      themes: [ "color", "gauge", "su3" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/search requires q parameter" do
    get api_v1_search_url, as: :json
    assert_response :bad_request
    assert_equal "blank_query", response.parsed_body.dig("error", "code")
  end

  test "GET /api/v1/search returns results for keyword search" do
    get api_v1_search_url, params: { q: "color", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "keyword", json.dig("meta", "mode")
  end

  test "GET /api/v1/subatomic_particles/search performs keyword search" do
    get search_api_v1_subatomic_particles_url, params: { q: "Up", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Up", json["data"].first["name"]
  end

  test "GET /api/v1/quantum_states/search performs keyword search" do
    get search_api_v1_quantum_states_url, params: { q: "gauge", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal @quantum_state.id, json["data"].first["id"]
  end
end

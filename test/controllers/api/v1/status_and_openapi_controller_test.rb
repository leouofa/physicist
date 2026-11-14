# frozen_string_literal: true

require "test_helper"

class Api::V1::StatusAndOpenapiControllerTest < ActionDispatch::IntegrationTest
  test "GET /api/v1/status returns ok status and platform stats" do
    get api_v1_status_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "ok", json.dig("data", "status")
    assert json.dig("data", "counts").key?("subatomic_particles")
    assert json.dig("data", "counts").key?("particle_groups")
    assert json.dig("data", "counts").key?("quantum_states")
    assert json.dig("data", "config").key?("context_window")
  end

  test "GET /api/v1/openapi returns valid OpenAPI 3.1 schema" do
    get api_v1_openapi_spec_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "3.1.0", json["openapi"]
    assert_equal "Physicist Platform REST API", json.dig("info", "title")
    assert json["paths"].key?("/status")
    assert json["paths"].key?("/particle_groups")
    assert json["paths"].key?("/subatomic_particles")
    assert json["paths"].key?("/quantum_states")
    assert json["paths"].key?("/clusters")
    assert json["paths"].key?("/cluster_snapshots")
    assert json["paths"].key?("/cluster_reports")
  end
end

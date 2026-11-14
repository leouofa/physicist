# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateParticleGroupsJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "perform runs agent, upserts particle_groups, and broadcasts Turbo Stream updates" do
    ParticleGroup.create!(name: "Quarks", description: "Initial Quarks description")

    fake_response = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Let me list major particle groups.</think>
        ```json
        {
          "particle_groups": [
            { "name": "Quarks", "description": "Fundamental elementary constituents of hadrons." },
            { "name": "Leptons", "description": "Elementary particles of half-integer spin that do not undergo strong interactions." }
          ]
        }
        ```
      TEXT
    )

    received_existing_names = nil
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| fake_response }

    with_stubbed_agent_create(->(existing_names:) {
      received_existing_names = existing_names
      fake_chat
    }) do
      assert_broadcasts(PopulateParticleGroupsJob::STREAM_NAME, 2) do
        PopulateParticleGroupsJob.perform_now
      end
    end

    assert_equal [ "Quarks" ], received_existing_names
    assert_equal 2, ParticleGroup.count
    assert_equal "Fundamental elementary constituents of hadrons.", ParticleGroup.find_by!(name: "Quarks").description
    assert_equal "Elementary particles of half-integer spin that do not undergo strong interactions.", ParticleGroup.find_by!(name: "Leptons").description
  end

  test "perform broadcasts error status and recovers gracefully when LLM fails" do
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| raise "LLM connection refused" }

    with_stubbed_agent_create(->(**) { fake_chat }) do
      assert_broadcasts(PopulateParticleGroupsJob::STREAM_NAME, 2) do
        assert_nothing_raised { PopulateParticleGroupsJob.perform_now }
      end
    end
  end

  test "perform broadcasts error status when LLM returns invalid non-JSON text" do
    fake_response = OpenStruct.new(parsed: nil, content: "Sorry, I cannot help with that.")
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| fake_response }

    with_stubbed_agent_create(->(**) { fake_chat }) do
      assert_broadcasts(PopulateParticleGroupsJob::STREAM_NAME, 2) do
        assert_nothing_raised { PopulateParticleGroupsJob.perform_now }
      end
    end

    assert_equal 0, ParticleGroup.count
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = ParticleGroupDiscoveryAgent.singleton_class
    original = ParticleGroupDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end

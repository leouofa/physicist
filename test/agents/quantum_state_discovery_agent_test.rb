# frozen_string_literal: true

require "test_helper"

class QuantumStateDiscoveryAgentTest < ActiveSupport::TestCase
  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end

    Llm::ModelRegistry.ensure_configured_model!(model_id: @model_id)
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "create! includes subatomic_particle context, particle_group name, existing state names, and Zeeman eigenstate JSON example" do
    chat = QuantumStateDiscoveryAgent.create!(
      subatomic_particle_name: "Electron",
      subatomic_particle_description: "Lightest charged lepton.",
      subatomic_particle_themes: [ "lepton", "negative charge", "spin 1/2" ],
      particle_group_name: "Leptons",
      existing_names: [ "Spin-Up", "Spin-Down" ]
    )

    assert chat.persisted?
    assert_nil chat.schema

    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "Electron"
    assert_includes system_message.content, "Leptons"
    assert_includes system_message.content, "Lightest charged lepton."
    assert_includes system_message.content, "lepton, negative charge, spin 1/2"
    assert_includes system_message.content, "Spin-Up, Spin-Down"
    assert_includes system_message.content, "Spin-Up (|↑⟩, ms = +1/2) Zeeman Eigenstate"
    assert_includes system_message.content, '"quantum_states"'
    assert_includes system_message.content, '"themes"'
  end
end

# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateQuantumStatesJobTest < ActiveSupport::TestCase
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

  test "perform iterates through subatomic_particles, upserts quantum_states with themes, and streams progress" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    up = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.", themes: [ "quark" ])
    down = SubatomicParticle.create!(particle_group: group, name: "Down", description: "Down quark.", themes: [ "quark" ])
    QuantumState.create!(subatomic_particle: up, name: "Red Color Charge", description: "Initial Red Color description", themes: [ "color" ])

    calls = []
    responses = {
      "Up" => <<~TEXT,
        <think>Listing Up quantum states.</think>
        ```json
        {
          "quantum_states": [
            { "name": "Red Color Charge", "description": "SU(3) red color charge eigenstate.", "themes": ["color", "su3"] },
            { "name": "Blue Color Charge", "description": "SU(3) blue color eigenstate.", "themes": ["color", "eigenstate"] }
          ]
        }
        ```
      TEXT
      "Down" => {
        "quantum_states" => [
          { "name": "Green Color Charge", "description": "SU(3) green color eigenstate.", "themes": [ "color", "gauge" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(subatomic_particle_name:, subatomic_particle_description:, subatomic_particle_themes:, particle_group_name:, existing_names:) {
      calls << {
        subatomic_particle_name: subatomic_particle_name,
        subatomic_particle_description: subatomic_particle_description,
        subatomic_particle_themes: subatomic_particle_themes,
        particle_group_name: particle_group_name,
        existing_names: existing_names
      }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(subatomic_particle_name))
      end
      fake_chat
    }) do
      # 2 subatomic_particles * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateQuantumStatesJob::STREAM_NAME, 6) do
        PopulateQuantumStatesJob.perform_now
      end
    end

    assert_equal [ "Down", "Up" ], calls.map { |c| c[:subatomic_particle_name] }
    assert_equal [], calls.first[:existing_names]
    assert_equal [ "Red Color Charge" ], calls.second[:existing_names]

    assert_equal 3, QuantumState.count
    red = up.quantum_states.find_by!(name: "Red Color Charge")
    assert_equal "SU(3) red color charge eigenstate.", red.description
    assert_equal [ "color", "su3" ], red.themes

    green = down.quantum_states.find_by!(name: "Green Color Charge")
    assert_equal [ "color", "gauge" ], green.themes
  end

  test "perform continues to remaining subatomic_particles if one subatomic_particle fails" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    up = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")
    down = SubatomicParticle.create!(particle_group: group, name: "Down", description: "Down quark.")

    with_stubbed_agent_create(->(subatomic_particle_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Up" if subatomic_particle_name == "Up"

        OpenStruct.new(
          parsed: nil,
          content: {
            "quantum_states" => [
              { "name": "Green Color Charge", "description": "SU(3) green eigenstate.", "themes": [ "color" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateQuantumStatesJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateQuantumStatesJob.perform_now }
      end
    end

    assert_equal 1, QuantumState.count
    assert_equal "Green Color Charge", QuantumState.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = QuantumStateDiscoveryAgent.singleton_class
    original = QuantumStateDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end

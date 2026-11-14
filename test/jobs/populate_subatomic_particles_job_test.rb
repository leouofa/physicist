# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateSubatomicParticlesJobTest < ActiveSupport::TestCase
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

  test "perform iterates through particle_groups, upserts subatomic_particles with themes, and streams progress" do
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    leptons = ParticleGroup.create!(name: "Leptons", description: "Elementary particles of spin 1/2.")
    SubatomicParticle.create!(particle_group: quarks, name: "Up", description: "Initial Up description", themes: [ "quark" ])

    calls = []
    responses = {
      "Quarks" => <<~TEXT,
        <think>Listing Quarks particles.</think>
        ```json
        {
          "subatomic_particles": [
            { "name": "Up", "description": "Lightest quark.", "themes": ["quark", "fractional charge"] },
            { "name": "Down", "description": "Second lightest quark.", "themes": ["quark", "isospin"] }
          ]
        }
        ```
      TEXT
      "Leptons" => {
        "subatomic_particles" => [
          { "name": "Electron", "description": "Lightest charged lepton.", "themes": [ "lepton", "stable" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(particle_group_name:, particle_group_description:, existing_names:) {
      calls << { particle_group_name: particle_group_name, particle_group_description: particle_group_description, existing_names: existing_names }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(particle_group_name))
      end
      fake_chat
    }) do
      # 2 particle_groups * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateSubatomicParticlesJob::STREAM_NAME, 6) do
        PopulateSubatomicParticlesJob.perform_now
      end
    end

    assert_equal [ "Leptons", "Quarks" ], calls.map { |c| c[:particle_group_name] } # ParticleGroup.ordered sorts alphabetically
    assert_equal [], calls.first[:existing_names] # Leptons has none initially
    assert_equal [ "Up" ], calls.second[:existing_names] # Quarks has Up

    assert_equal 3, SubatomicParticle.count
    up = quarks.subatomic_particles.find_by!(name: "Up")
    assert_equal "Lightest quark.", up.description
    assert_equal [ "quark", "fractional charge" ], up.themes

    electron = leptons.subatomic_particles.find_by!(name: "Electron")
    assert_equal [ "lepton", "stable" ], electron.themes
  end

  test "perform continues to remaining particle_groups if one particle_group fails" do
    leptons = ParticleGroup.create!(name: "Leptons", description: "Elementary particles of spin 1/2.")
    quarks = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")

    with_stubbed_agent_create(->(particle_group_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Quarks" if particle_group_name == "Quarks"

        OpenStruct.new(
          parsed: nil,
          content: {
            "subatomic_particles" => [
              { "name": "Electron", "description": "Lightest charged lepton.", "themes": [ "lepton" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateSubatomicParticlesJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateSubatomicParticlesJob.perform_now }
      end
    end

    assert_equal 1, SubatomicParticle.count
    assert_equal "Electron", SubatomicParticle.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = SubatomicParticleDiscoveryAgent.singleton_class
    original = SubatomicParticleDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end

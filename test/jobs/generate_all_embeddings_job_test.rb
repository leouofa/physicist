# frozen_string_literal: true

require "test_helper"

class GenerateAllEmbeddingsJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform with only_missing: true skips already-embedded subatomic_particles and embeds missing ones" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    existing_vector = Array.new(1024, 0.1)
    up = SubatomicParticle.create!(
      particle_group: group,
      name: "Up",
      description: "Lightest quark.",
      embedding: existing_vector,
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    down = SubatomicParticle.create!(particle_group: group, name: "Down", description: "Down quark.")

    new_vector = Array.new(1024, 0.2)
    called_texts = []

    with_stubbed_generator(->(text) {
      called_texts << text
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 2) do
        GenerateAllEmbeddingsJob.perform_now("SubatomicParticle", only_missing: true)
      end
    end

    assert_equal 1, called_texts.size
    assert_match "Down", called_texts.first
    assert_equal "old-model", up.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", down.reload.embedding_model
  end

  test "perform with only_missing: false regenerates all quantum_states" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    up = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")
    down = SubatomicParticle.create!(particle_group: group, name: "Down", description: "Down quark.")

    state1 = QuantumState.create!(
      subatomic_particle: up,
      name: "Red Color Charge",
      description: "SU(3) color eigenstate.",
      themes: [ "color" ],
      embedding: Array.new(1024, 0.1),
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    state2 = QuantumState.create!(subatomic_particle: down, name: "Blue Color Charge", description: "SU(3) color eigenstate.", themes: [ "color" ])

    new_vector = Array.new(1024, 0.3)
    called_count = 0

    with_stubbed_generator(->(_text) {
      called_count += 1
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 3) do
        GenerateAllEmbeddingsJob.perform_now("QuantumState", only_missing: false)
      end
    end

    assert_equal 2, called_count
    assert_equal "qwen3-embedding:0.6b", state1.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", state2.reload.embedding_model
  end

  test "perform continues remaining records when one record fails" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    up = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.")
    down = SubatomicParticle.create!(particle_group: group, name: "Down", description: "Down quark.")

    new_vector = Array.new(1024, 0.4)

    with_stubbed_generator(->(text) {
      raise "Temporary timeout" if text.include?("Up")

      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 3) do
        GenerateAllEmbeddingsJob.perform_now("SubatomicParticle", only_missing: true)
      end
    end

    assert_not up.reload.embedded?
    assert down.reload.embedded?
  end

  test "perform broadcasts info message when nothing needs embedding" do
    assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 1) do
      GenerateAllEmbeddingsJob.perform_now("SubatomicParticle", only_missing: true)
    end
  end

  private

  def with_stubbed_generator(replacement)
    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call, &replacement)
    yield
  ensure
    singleton.define_method(:call, original)
  end
end

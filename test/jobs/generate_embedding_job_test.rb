# frozen_string_literal: true

require "test_helper"

class GenerateEmbeddingJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform generates embedding for SubatomicParticle and broadcasts running and success states" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.", themes: [ "fermion", "fractional charge" ])
    vector = Array.new(1024, 0.05)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(particle), 2) do
        GenerateEmbeddingJob.perform_now("SubatomicParticle", particle.id)
      end
    end

    particle.reload
    assert particle.embedded?
    assert_equal "qwen3-embedding:0.6b", particle.embedding_model
    assert_not_nil particle.embedded_at
    assert_equal 1024, particle.embedding.size
  end

  test "perform generates embedding for QuantumState and broadcasts running and success states" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Up", description: "Lightest quark.", themes: [ "fermion" ])
    state = QuantumState.create!(subatomic_particle: particle, name: "Red Color Charge", description: "SU(3) color eigenstate.", themes: [ "color" ])
    vector = Array.new(1024, 0.02)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(state), 2) do
        GenerateEmbeddingJob.perform_now("QuantumState", state.id)
      end
    end

    state.reload
    assert state.embedded?
    assert_equal "qwen3-embedding:0.6b", state.embedding_model
    assert_not_nil state.embedded_at
    assert_equal 1024, state.embedding.size
  end

  test "perform broadcasts error state when embedding generation fails" do
    group = ParticleGroup.create!(name: "Quarks", description: "Fundamental elementary particles.")
    particle = SubatomicParticle.create!(particle_group: group, name: "Down", description: "Down quark.")

    with_stubbed_generator(->(_text) { raise "Connection refused" }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(particle), 2) do
        GenerateEmbeddingJob.perform_now("SubatomicParticle", particle.id)
      end
    end

    assert_not particle.reload.embedded?
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

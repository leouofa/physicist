# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @particle_groups = ParticleGroup.ordered
  end

  def subatomic_particles
    @particle_group_groups = SubatomicParticle.grouped_by_particle_group
    @total_subatomic_particles_count = SubatomicParticle.count
    @particle_groups_count = ParticleGroup.count
  end

  def quantum_states
    @subatomic_particle_groups = QuantumState.grouped_by_subatomic_particle
    @total_quantum_states_count = QuantumState.count
    @subatomic_particles_count = SubatomicParticle.count
  end
end

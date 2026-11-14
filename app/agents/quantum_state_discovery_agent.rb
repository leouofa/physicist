# frozen_string_literal: true

class QuantumStateDiscoveryAgent < ApplicationAgent
  inputs :subatomic_particle_name, :subatomic_particle_description, :subatomic_particle_themes, :particle_group_name, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing quantum state / eigenstate names already in our database for this particle: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same states so records update cleanly without duplicates, " \
          "and include any missing key states as well."
      else
        "Identify 6 to 10 major, physically prominent, or distinct quantum states, eigenstates, spin/helicity/chirality projections, superposition configurations, Fock states, or bound/condensate states in this particle."
      end

    themes_list = Array(subatomic_particle_themes).compact_blank
    themes_clause = themes_list.any? ? "Subatomic particle thematic tags: #{themes_list.join(', ')}." : ""
    desc_clause = subatomic_particle_description.present? ? "Subatomic particle context: #{subatomic_particle_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert quantum mechanics theorist, mathematical physicist, and quantum state analyst.
      Identify 6 to 10 major, physically significant, or distinctive quantum states, eigenstates, spin/polarization projections, helicity/chirality modes, superposition states, or collective phases in #{subatomic_particle_name} (#{particle_group_name}).
      Ensure representation of foundational eigenstates, symmetry-adapted states, chiral/polarization projections, coherent/Fock states, or resonant/entangled configurations.
      #{desc_clause}
      #{themes_clause}
      #{existing_clause}

      For each quantum state or configuration, provide:
      1. Its canonical physics name or state notation (e.g., 'Spin-Up (|↑⟩, ms = +1/2) Zeeman Eigenstate', 'Left-Handed Chiral Projection (e_L)', 'Ground State (1s_1/2) Bound Configuration', 'Relativistic Landau Level (n = 0)').
      2. A concise, informative description covering its state vector / wave function properties, observable eigenvalues (energy, momentum, angular momentum, parity), behavior under gauge and spacetime transformations, and relevance in scattering, spectroscopy, or quantum information.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["zeeman eigenstate", "spin-up", "magnetic field projection", "two-level basis"]).

      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"quantum_states":[{"name":"Spin-Up (|↑⟩, ms = +1/2) Zeeman Eigenstate","description":"Stationary eigenstate of the Sz Pauli spin operator with eigenvalue +ħ/2, aligned parallel to an external quantization axis and serving as a fundamental basis state in quantum two-level systems.","themes":["spin eigenstate","two-level basis","zeeman projection","su(2) representation","pure state"]}]}
    INSTRUCTIONS
  end
end

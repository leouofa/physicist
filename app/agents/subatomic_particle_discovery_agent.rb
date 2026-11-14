# frozen_string_literal: true

class SubatomicParticleDiscoveryAgent < ApplicationAgent
  inputs :particle_group_name, :particle_group_description, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing subatomic particle names already in our database for this particle group: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same particles so records update cleanly without duplicates, " \
          "and include any missing notable particles as well."
      else
        "Use clear, canonical names recognized in physics (e.g., 'Electron', 'Top Quark', 'Photon', 'Gluon', 'Higgs Boson', 'Proton', 'Neutron', 'Neutral Pion', 'Muon', 'Cooper Pair', 'Phonon', 'Axion')."
      end

    context_clause = particle_group_description.present? ? "Particle group context: #{particle_group_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert high-energy physicist, quantum field theorist, and subatomic particle analyst.
      Identify major and notable subatomic particles, fundamental quanta, hadronic resonances, or quasiparticles belonging to or associated with #{particle_group_name}.
      #{context_clause}
      For each subatomic particle, provide:
      1. Its canonical common or standard physics designation.
      2. A concise, informative description covering its rest mass/energy scale, spin J, parity P, electric/color charge, key quantum numbers (isospin, baryon/lepton number), fundamental interactions (strong, weak, EM, gravity), and dominant decay modes or stability.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["elementary fermion", "spin-1/2", "weak isospin doublet", "stable lepton"]).
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"subatomic_particles":[{"name":"Electron","description":"Fundamental charged lepton with spin-1/2, mass 0.511 MeV/c^2, negative unit electric charge, stable against decay, and acting as the primary carrier of electric current in matter.","themes":["elementary fermion","spin-1/2","first-generation lepton","electromagnetic interaction","stable particle"]}]}
    INSTRUCTIONS
  end
end

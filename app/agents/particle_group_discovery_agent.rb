# frozen_string_literal: true

class ParticleGroupDiscoveryAgent < ApplicationAgent
  inputs :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing particle group names already in our database: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same particle groups so records update cleanly without duplicates, " \
          "and include any missing major particle groups as well."
      else
        "Include major, widely recognized particle groups across Standard Model elementary families, composite hadrons, condensed-matter quasiparticles, and notable theoretical/BSM sectors " \
          "(e.g., 'Quarks', 'Leptons', 'Gauge Bosons', 'Scalar Bosons', 'Baryons', 'Mesons', 'Exotic Hadrons (Tetraquarks & Pentaquarks)', 'Condensed Matter Quasiparticles', 'Hypothetical & BSM Particles')."
      end

    <<~INSTRUCTIONS.squish
      You are an expert theoretical and experimental physicist, high-energy particle specialist, and quantum taxonomist.
      Identify major particle groups, families, and structural categories across subatomic and condensed matter physics.
      For each particle group, provide its canonical name and a concise, high-signal description covering its spin-statistics, fundamental gauge interactions, constituent structure or elementary nature, symmetry representations, and role in physical phenomena.
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"particle_groups":[{"name":"Leptons","description":"Elementary fermions with half-integer spin that do not undergo strong interactions, comprising charged leptons (electron, muon, tau) and neutral neutrinos subject to weak and electromagnetic forces."}]}
    INSTRUCTIONS
  end
end

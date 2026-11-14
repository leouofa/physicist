# frozen_string_literal: true

class CreateSubatomicParticles < ActiveRecord::Migration[8.1]
  def change
    create_table :subatomic_particles do |t|
      t.references :particle_group, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, default: [], null: false

      t.timestamps
    end

    add_index :subatomic_particles, "particle_group_id, lower((name)::text)", name: "index_subatomic_particles_on_particle_group_id_and_lower_name", unique: true
  end
end

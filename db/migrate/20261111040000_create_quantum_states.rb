# frozen_string_literal: true

class CreateQuantumStates < ActiveRecord::Migration[8.1]
  def change
    create_table :quantum_states do |t|
      t.references :subatomic_particle, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, default: [], null: false

      t.timestamps
    end

    add_index :quantum_states, "subatomic_particle_id, lower((name)::text)", name: "index_quantum_states_on_subatomic_particle_id_and_lower_name", unique: true
  end
end

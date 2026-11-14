# frozen_string_literal: true

class CreateParticleGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :particle_groups do |t|
      t.string :name, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :particle_groups, "lower((name)::text)", name: "index_particle_groups_on_lower_name", unique: true
  end
end

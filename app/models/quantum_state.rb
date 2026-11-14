# frozen_string_literal: true

class QuantumState < ApplicationRecord
  include Embeddable

  belongs_to :subatomic_particle
  has_one :particle_group, through: :subatomic_particle

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :description, with: ->(value) { value.to_s.strip }
  normalizes :themes, with: ->(value) { normalize_themes(value) }

  validates :name, presence: true, uniqueness: { scope: :subatomic_particle_id, case_sensitive: false }
  validates :description, presence: true
  validate :themes_must_be_string_array

  scope :ordered, -> { order(:name) }

  def embedding_input
    lines = [
      "Quantum State / Eigenstate: #{name} (#{subatomic_particle.name}, #{subatomic_particle.particle_group.name})",
      "Description: #{description}"
    ]
    lines << "Themes: #{themes.join(', ')}" if themes.any?
    lines.join("\n")
  end

  # Returns [subatomic_particle, Array<QuantumState>] pairs ordered by particle group name then subatomic particle name then quantum state name.
  def self.grouped_by_subatomic_particle
    includes(subatomic_particle: :particle_group)
      .joins(subatomic_particle: :particle_group)
      .order("particle_groups.name ASC, subatomic_particles.name ASC, quantum_states.name ASC")
      .group_by(&:subatomic_particle)
      .to_a
  end

  # Upserts an enumerable of { name:, description:, themes: } entries scoped to
  # the given subatomic particle, matching case-insensitively on normalized name.
  def self.upsert_batch!(subatomic_particle, entries)
    raise ArgumentError, "subatomic_particle must be present" if subatomic_particle.nil?

    transaction do
      Array(entries).filter_map do |entry|
        attrs = entry.respond_to?(:to_h) ? entry.to_h.symbolize_keys : {}
        name = attrs[:name].to_s.squish
        description = attrs[:description].to_s.strip
        next if name.blank? || description.blank?

        themes = normalize_themes(attrs[:themes])
        upsert_one!(subatomic_particle: subatomic_particle, name: name, description: description, themes: themes)
      end
    end
  end

  def self.normalize_themes(value)
    items =
      case value
      when Array
        value
      when String
        value.split(",")
      else
        []
      end

    items.filter_map { |item| item.to_s.squish.presence }.uniq(&:downcase)
  end

  def self.upsert_one!(subatomic_particle:, name:, description:, themes:)
    scope = subatomic_particle.quantum_states
    record = scope.where("LOWER(name) = ?", name.downcase).first_or_initialize
    record.assign_attributes(name: name, description: description, themes: themes)
    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    record = scope.where("LOWER(name) = ?", name.downcase).first!
    record.update!(name: name, description: description, themes: themes)
    record
  end
  private_class_method :upsert_one!

  private

  def themes_must_be_string_array
    unless themes.is_a?(Array) && themes.all? { |item| item.is_a?(String) && item.present? }
      errors.add(:themes, "must be a list of non-empty strings")
    end
  end
end

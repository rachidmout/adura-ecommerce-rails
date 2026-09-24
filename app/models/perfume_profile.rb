class PerfumeProfile < ApplicationRecord
  AUDIENCES = %w[women men unisex].freeze
  INTENSITIES = %w[soft moderate intense].freeze
  LONGEVITIES = %w[short moderate long].freeze
  SILLAGES = %w[intimate moderate strong].freeze
  SEASONS = %w[spring summer autumn winter].freeze
  OCCASIONS = %w[daily work evening special gift].freeze

  belongs_to :product

  validates :audience, inclusion: { in: AUDIENCES }
  validates :intensity_level, inclusion: { in: INTENSITIES }, allow_blank: true
  validates :longevity_level, inclusion: { in: LONGEVITIES }, allow_blank: true
  validates :sillage_level, inclusion: { in: SILLAGES }, allow_blank: true
  validate :controlled_array_values

  private

  def controlled_array_values
    errors.add(:season_codes, "contient une valeur inconnue") if season_codes.any? { |code| !SEASONS.include?(code) }
    errors.add(:occasion_codes, "contient une valeur inconnue") if occasion_codes.any? { |code| !OCCASIONS.include?(code) }
  end
end

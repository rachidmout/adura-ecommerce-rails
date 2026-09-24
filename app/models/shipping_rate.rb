class ShippingRate < ApplicationRecord
  belongs_to :shipping_method

  validates :min_weight_grams, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_weight_grams, numericality: { only_integer: true, greater_than: :min_weight_grams }, allow_nil: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :weight_range_does_not_overlap

  private

  def weight_range_does_not_overlap
    return unless shipping_method && min_weight_grams.present?

    shipping_method.shipping_rates.where.not(id: id).find_each do |rate|
      next unless weight_ranges_overlap?(rate)

      errors.add(:base, "chevauche une tranche existante")
      break
    end
  end

  def weight_ranges_overlap?(other)
    upper_bound = max_weight_grams || Float::INFINITY
    other_upper_bound = other.max_weight_grams || Float::INFINITY

    min_weight_grams <= other_upper_bound && other.min_weight_grams <= upper_bound
  end
end

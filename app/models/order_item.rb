class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product_variant, optional: true

  validates :product_name, :brand_name, :variant_label, :sku, presence: true
  validates :volume_ml, :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, :line_total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :line_total_matches

  private

  def line_total_matches
    errors.add(:line_total_cents, "ne correspond pas au prix et à la quantité") unless line_total_cents == unit_price_cents * quantity
  end
end

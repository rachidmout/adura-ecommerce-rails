class ShopSetting < ApplicationRecord
  belongs_to :updated_by_admin_user, class_name: "AdminUser", optional: true

  validates :code, presence: true, uniqueness: true
  validates :shipping_rate_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :free_shipping_threshold_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :base_packaging_weight_grams, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :currency, inclusion: { in: %w[EUR] }
  validates :shipping_country_code, inclusion: { in: %w[FR] }

  def self.current
    find_or_create_by!(code: "default")
  end

  def shipping_for(subtotal_cents)
    return 0 if free_shipping_threshold_cents.present? && subtotal_cents >= free_shipping_threshold_cents

    shipping_rate_cents
  end
end

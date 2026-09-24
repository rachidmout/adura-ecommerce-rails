class PromoCodeProduct < ApplicationRecord
  belongs_to :promo_code
  belongs_to :product

  validates :product_id, uniqueness: { scope: :promo_code_id }
end

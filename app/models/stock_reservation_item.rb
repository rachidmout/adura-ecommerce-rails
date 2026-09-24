class StockReservationItem < ApplicationRecord
  belongs_to :stock_reservation
  belongs_to :product_variant

  validates :product_variant_id, uniqueness: { scope: :stock_reservation_id }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
end

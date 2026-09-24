class StockReservation < ApplicationRecord
  belongs_to :payment
  has_many :stock_reservation_items, dependent: :restrict_with_error

  enum :state, {
    pending_session: "pending_session",
    active: "active",
    consumed: "consumed",
    released: "released"
  }, validate: true

  validates :expires_at, presence: true
end

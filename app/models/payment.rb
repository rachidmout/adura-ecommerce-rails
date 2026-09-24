class Payment < ApplicationRecord
  belongs_to :order
  has_many :payment_events, dependent: :nullify
  has_one :stock_reservation, dependent: :restrict_with_error

  enum :status, {
    pending: "pending",
    succeeded: "succeeded",
    failed: "failed",
    expired: "expired"
  }, validate: true

  validates :provider, inclusion: { in: %w[stripe] }
  validates :checkout_session_id, uniqueness: true, allow_nil: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, inclusion: { in: %w[EUR] }
end

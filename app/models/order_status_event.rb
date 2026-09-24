class OrderStatusEvent < ApplicationRecord
  belongs_to :order
  belongs_to :admin_user, optional: true

  validates :to_status, :source, presence: true
  validates :source, inclusion: { in: %w[checkout stripe admin system] }
end

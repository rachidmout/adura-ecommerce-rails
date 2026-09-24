class ShippingZone < ApplicationRecord
  has_many :shipping_zone_countries, dependent: :restrict_with_error
  has_many :shipping_methods, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end

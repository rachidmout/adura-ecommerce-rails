class OrderRelayPoint < ApplicationRecord
  belongs_to :order

  normalizes :carrier, :relay_id, :relay_name, :relay_address_line1, :relay_address_line2,
             :relay_postal_code, :relay_city, :relay_country, with: ->(value) { value.to_s.strip.presence }
  normalizes :relay_country, with: ->(value) { value.to_s.strip.upcase.presence }

  validates :carrier, :relay_id, :relay_name, :relay_address_line1, :relay_postal_code, :relay_city, :relay_country, presence: true
  validates :relay_country, format: { with: /\A[A-Z]{2}\z/ }

  def formatted_address
    [ relay_address_line1, relay_address_line2, "#{relay_postal_code} #{relay_city}", relay_country ].compact_blank.join("\n")
  end
end

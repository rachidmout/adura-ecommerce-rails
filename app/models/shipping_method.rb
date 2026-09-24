class ShippingMethod < ApplicationRecord
  KINDS = %w[home_delivery pickup_point].freeze
  PROVIDERS = %w[direct sendcloud].freeze

  belongs_to :shipping_zone
  has_many :shipping_rates, dependent: :restrict_with_error

  normalizes :name, :carrier_name, :provider, :provider_method_id_override, with: ->(value) { value.to_s.strip }
  normalizes :provider_carrier_code, with: ->(value) { value.to_s.strip.downcase.presence }

  validates :name, :carrier_name, presence: true
  validates :name, uniqueness: { scope: :shipping_zone_id, case_sensitive: false }
  validates :kind, inclusion: { in: KINDS }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :provider_carrier_code, presence: true, if: :sendcloud?
  validates :provider_carrier_code, format: { with: /\A[a-z0-9_-]+\z/, message: "doit être un code transporteur Sendcloud valide" }, if: :sendcloud?, allow_blank: true
  validates :provider_method_id_override, format: { with: /\A[1-9]\d*\z/, message: "doit être un identifiant Sendcloud numérique positif" }, allow_blank: true
  validates :free_shipping_threshold_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def pickup_point?
    kind == "pickup_point"
  end

  def home_delivery?
    kind == "home_delivery"
  end

  def sendcloud?
    provider == "sendcloud"
  end

  def provider_method_id_override?
    provider_method_id_override.present?
  end
end

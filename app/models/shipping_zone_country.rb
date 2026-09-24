class ShippingZoneCountry < ApplicationRecord
  COUNTRIES = {
    "FR" => "France",
    "BE" => "Belgique",
    "LU" => "Luxembourg",
    "NL" => "Pays-Bas",
    "DE" => "Allemagne",
    "ES" => "Espagne",
    "PT" => "Portugal",
    "IT" => "Italie",
    "MA" => "Maroc"
  }.freeze

  belongs_to :shipping_zone

  normalizes :country_code, with: ->(country_code) { country_code.to_s.strip.upcase }

  validates :country_code, presence: true, uniqueness: true
  validate :country_code_is_iso_3166_alpha_2

  private

  def country_code_is_iso_3166_alpha_2
    return if country_code.blank?

    TZInfo::Country.get(country_code)
  rescue TZInfo::InvalidCountryCode
    errors.add(:country_code, "doit être un code ISO 3166-1 alpha-2 valide")
  end
end

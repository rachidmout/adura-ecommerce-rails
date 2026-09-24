module Checkout
  class SupportedCountries
    def self.codes
      return [ "FR" ] unless ShippingMethodsFeature.enabled?

      ShippingZone.where(active: true)
                  .joins(:shipping_zone_countries, shipping_methods: :shipping_rates)
                  .where(shipping_methods: { active: true }, shipping_rates: { active: true })
                  .distinct
                  .pluck("shipping_zone_countries.country_code")
    end

    def self.allowed?(country_code)
      codes.include?(country_code.to_s.upcase)
    end
  end
end

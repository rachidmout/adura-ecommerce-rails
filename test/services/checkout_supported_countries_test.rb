require "test_helper"

class CheckoutSupportedCountriesTest < ActiveSupport::TestCase
  test "falls back safely to France when no active zone is configured" do
    assert_equal [ "FR" ], Checkout::SupportedCountries.codes
  end

  test "uses France from an active zone and excludes inactive zones" do
    active_zone = ShippingZone.create!(name: "France active", active: true)
    active_zone.shipping_zone_countries.create!(country_code: "FR")
    inactive_zone = ShippingZone.create!(name: "Belgique inactive", active: false)
    inactive_zone.shipping_zone_countries.create!(country_code: "BE")

    with_shipping_methods_feature do
      active_zone.shipping_methods.create!(name: "Standard", carrier_name: "Colissimo", active: true).shipping_rates.create!(min_weight_grams: 0, price_cents: 690, active: true)
      assert_equal [ "FR" ], Checkout::SupportedCountries.codes
      assert Checkout::SupportedCountries.allowed?("fr")
      assert_not Checkout::SupportedCountries.allowed?("BE")
    end
  end

  test "exposes exactly the countries with an active configured rate" do
    configured_countries = %w[FR BE LU NL DE ES PT IT MA]
    france = ShippingZone.create!(name: "France configured", active: true)
    europe = ShippingZone.create!(name: "Europe configured", active: true)
    morocco = ShippingZone.create!(name: "Morocco configured", active: true)
    { france => [ "FR" ], europe => %w[BE LU NL DE ES PT IT], morocco => [ "MA" ] }.each do |zone, country_codes|
      country_codes.each { |country_code| zone.shipping_zone_countries.create!(country_code: country_code) }
      zone.shipping_methods.create!(name: "Standard", carrier_name: "Colissimo", active: true).shipping_rates.create!(min_weight_grams: 0, price_cents: 590, active: true)
    end

    with_shipping_methods_feature do
      assert_equal configured_countries.sort, Checkout::SupportedCountries.codes.sort
      assert_not Checkout::SupportedCountries.allowed?("CH")
    end
  end

  private

  def with_shipping_methods_feature
    previous_value = ENV["CHECKOUT_SHIPPING_METHODS_ENABLED"]
    ENV["CHECKOUT_SHIPPING_METHODS_ENABLED"] = "true"
    yield
  ensure
    ENV["CHECKOUT_SHIPPING_METHODS_ENABLED"] = previous_value
  end
end

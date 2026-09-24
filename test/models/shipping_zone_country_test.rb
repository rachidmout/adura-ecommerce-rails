require "test_helper"

class ShippingZoneCountryTest < ActiveSupport::TestCase
  test "normalizes and accepts supported future ISO country codes" do
    zone = ShippingZone.create!(name: "International")

    %w[FR BE LU NL DE ES PT IT MA].each do |country_code|
      record = ShippingZoneCountry.new(shipping_zone: zone, country_code: country_code.downcase)
      assert record.valid?, "#{country_code} should be valid"
      assert_equal country_code, record.country_code
    end
  end

  test "rejects an invalid ISO country code" do
    country = ShippingZoneCountry.new(shipping_zone: ShippingZone.create!(name: "Zone test"), country_code: "ZZ")

    assert_not country.valid?
    assert_includes country.errors[:country_code], "doit être un code ISO 3166-1 alpha-2 valide"
  end

  test "does not allow a country in multiple zones" do
    ShippingZoneCountry.create!(shipping_zone: ShippingZone.create!(name: "France"), country_code: "FR")
    duplicate = ShippingZoneCountry.new(shipping_zone: ShippingZone.create!(name: "Europe"), country_code: "FR")

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:country_code]
  end
end

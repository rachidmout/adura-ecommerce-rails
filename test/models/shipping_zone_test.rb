require "test_helper"

class ShippingZoneTest < ActiveSupport::TestCase
  test "requires a unique case-insensitive name" do
    ShippingZone.create!(name: "France métropolitaine")

    duplicate = ShippingZone.new(name: " france métropolitaine ")
    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:name]
  end

  test "cannot be destroyed while it has countries or methods" do
    zone = ShippingZone.create!(name: "Zone test")
    zone.shipping_zone_countries.create!(country_code: "FR")

    assert_not zone.destroy
    assert_not_empty zone.errors[:base]
  end
end

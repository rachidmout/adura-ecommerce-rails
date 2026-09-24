require "test_helper"

module Admin
  class ShippingZonesControllerTest < ActionDispatch::IntegrationTest
    setup { sign_in_as(create_admin_user) }

    test "creates and activates a shipping zone" do
      assert_difference "ShippingZone.count", 1 do
        post admin_shipping_zones_path, params: { shipping_zone: { name: "France métropolitaine", active: "0" } }
      end

      zone = ShippingZone.find_by!(name: "France métropolitaine")
      assert_redirected_to admin_shipping_zone_path(zone)
      assert_not zone.active?

      patch activate_admin_shipping_zone_path(zone)
      assert zone.reload.active?
    end

    test "renders a zone with its country and method management" do
      zone = ShippingZone.create!(name: "France")

      get admin_shipping_zone_path(zone)

      assert_response :success
      assert_select "select[name='shipping_zone_country[country_code]']"
      assert_select "a[href=?]", new_admin_shipping_zone_shipping_method_path(zone), text: "Nouvelle méthode"
    end

    test "adds a country and refuses a country already in another zone" do
      france = ShippingZone.create!(name: "France")
      europe = ShippingZone.create!(name: "Europe")

      post admin_shipping_zone_shipping_zone_countries_path(france), params: { shipping_zone_country: { country_code: "FR" } }
      assert france.shipping_zone_countries.exists?(country_code: "FR")

      post admin_shipping_zone_shipping_zone_countries_path(europe), params: { shipping_zone_country: { country_code: "FR" } }
      assert_not_empty flash[:alert]
      assert_not europe.shipping_zone_countries.exists?(country_code: "FR")
    end
  end
end

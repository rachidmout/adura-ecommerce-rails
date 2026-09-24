require "test_helper"

module Admin
  class ShippingMethodsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(create_admin_user)
      @zone = ShippingZone.create!(name: "France")
    end

    test "creates a shipping method and converts its free threshold from euros" do
      assert_difference "ShippingMethod.count", 1 do
        post admin_shipping_zone_shipping_methods_path(@zone), params: {
          shipping_method: { name: "Livraison standard", carrier_name: "Colissimo / La Poste", free_shipping_threshold_euros: "50.00", active: "1" }
        }
      end

      method = @zone.shipping_methods.find_by!(name: "Livraison standard")
      assert_equal 5_000, method.free_shipping_threshold_cents
      assert method.active?
    end

    test "renders the method form with a euro threshold field" do
      get new_admin_shipping_zone_shipping_method_path(@zone)

      assert_response :success
      assert_select "input[name='shipping_method[free_shipping_threshold_euros]']"
      assert_select "select[name='shipping_method[kind]'] option[value='pickup_point']", text: "Point relais"
      assert_select "select[name='shipping_method[provider]'] option[value='sendcloud']", text: "Sendcloud"
      assert_select "input[name='shipping_method[provider_carrier_code]']"
      assert_select "input[name='shipping_method[provider_method_id_override]']"
    end

    test "creates a Sendcloud method with its stable carrier code and optional override" do
      post admin_shipping_zone_shipping_methods_path(@zone), params: {
        shipping_method: { name: "Relais Sendcloud", carrier_name: "Mondial Relay", kind: "pickup_point", provider: "sendcloud", provider_carrier_code: "mondial_relay", provider_method_id_override: "8", active: "1" }
      }

      method = @zone.shipping_methods.find_by!(name: "Relais Sendcloud")
      assert_predicate method, :sendcloud?
      assert_equal "mondial_relay", method.provider_carrier_code
      assert_equal "8", method.provider_method_id_override
    end

    test "activates and deactivates a method" do
      method = @zone.shipping_methods.create!(name: "Standard", carrier_name: "DHL")

      patch activate_admin_shipping_zone_shipping_method_path(@zone, method)
      assert method.reload.active?

      patch deactivate_admin_shipping_zone_shipping_method_path(@zone, method)
      assert_not method.reload.active?
    end
  end
end

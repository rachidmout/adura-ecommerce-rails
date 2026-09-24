require "test_helper"

module Admin
  class ShippingConfigurationsControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_shipping_configuration_path

      assert_redirected_to admin_login_path
    end

    test "renders the shipping configuration and updates optional packaging weight" do
      sign_in_as(create_admin_user)

      get admin_shipping_configuration_path
      assert_response :success
      assert_select "h1", "Configuration livraison"
      assert_select "input[name='shop_setting[base_packaging_weight_grams]']"

      patch packaging_admin_shipping_configuration_path, params: { shop_setting: { base_packaging_weight_grams: 180 } }

      assert_redirected_to admin_shipping_configuration_path
      assert_equal 180, ShopSetting.current.base_packaging_weight_grams
    end
  end
end

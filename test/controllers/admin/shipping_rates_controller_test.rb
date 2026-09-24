require "test_helper"

module Admin
  class ShippingRatesControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(create_admin_user)
      @zone = ShippingZone.create!(name: "France")
      @shipping_method = @zone.shipping_methods.create!(name: "Standard", carrier_name: "Colissimo")
    end

    test "creates an open-ended rate and converts euros to cents" do
      assert_difference "ShippingRate.count", 1 do
        post admin_shipping_zone_shipping_method_shipping_rates_path(@zone, @shipping_method), params: {
          shipping_rate: { min_weight_grams: 1_001, max_weight_grams: "", price_euros: "12.90", active: "1" }
        }
      end

      rate = @shipping_method.shipping_rates.last
      assert_nil rate.max_weight_grams
      assert_equal 1_290, rate.price_cents
      assert rate.active?
    end

    test "renders the rate form with an optional maximum weight" do
      get new_admin_shipping_zone_shipping_method_shipping_rate_path(@zone, @shipping_method)

      assert_response :success
      assert_select "input[name='shipping_rate[max_weight_grams]']"
      assert_select "input[name='shipping_rate[price_euros]']"
    end

    test "shows a useful error when a rate overlaps another range" do
      @shipping_method.shipping_rates.create!(min_weight_grams: 0, max_weight_grams: 500, price_cents: 690)

      assert_no_difference "ShippingRate.count" do
        post admin_shipping_zone_shipping_method_shipping_rates_path(@zone, @shipping_method), params: {
          shipping_rate: { min_weight_grams: 500, max_weight_grams: 1_000, price_euros: "8.90", active: "1" }
        }
      end

      assert_response :unprocessable_entity
      assert_select ".error-summary", /chevauche une tranche/
    end
  end
end

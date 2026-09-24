require "test_helper"

module Admin
  class PromoCodesControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_promo_codes_path
      assert_redirected_to admin_login_path
    end

    test "creates a promo code with product/family scoping" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(slug: "admin-promo-scope-test")

      assert_difference "PromoCode.count", 1 do
        post admin_promo_codes_path, params: {
          promo_code: { code: "ADMINTEST10", discount_type: "percentage", discount_value: 10, active: "1", product_ids: [ product.id ] }
        }
      end

      promo_code = PromoCode.find_by(code: "ADMINTEST10")
      assert_redirected_to admin_promo_codes_path
      assert_includes promo_code.products, product
    end

    test "rejects an invalid discount value" do
      sign_in_as(create_admin_user)

      assert_no_difference "PromoCode.count" do
        post admin_promo_codes_path, params: { promo_code: { code: "BADVALUE", discount_type: "percentage", discount_value: 0 } }
      end
      assert_response :unprocessable_entity
    end
  end
end

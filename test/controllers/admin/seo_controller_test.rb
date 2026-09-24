require "test_helper"

module Admin
  class SeoControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_seo_path
      assert_redirected_to admin_login_path
    end

    test "flags a product with missing SEO fields as incomplete" do
      sign_in_as(create_admin_user)
      create_publishable_product(slug: "seo-admin-incomplete-test")

      get admin_seo_path

      assert_response :success
      assert_select ".status-pill", text: "SEO à compléter"
    end
  end
end

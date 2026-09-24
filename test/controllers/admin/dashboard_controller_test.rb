require "test_helper"

module Admin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_root_path
      assert_redirected_to admin_login_path
    end

    test "renders KPIs and the sales chart for an authenticated admin" do
      admin = create_admin_user
      sign_in_as(admin)
      create_paid_order
      preparing = create_paid_order(status: :paid)
      preparing.mark_preparing!(admin_user: admin)
      shipped = create_paid_order(status: :paid)
      shipped.mark_shipped!(admin_user: admin, shipping_carrier: "Chronopost", tracking_number: "XY123456789FR")

      get admin_root_path

      assert_response :success
      assert_select "h1", /Tableau de bord/
      assert_select ".admin-title + .admin-grid > .admin-card", count: 9
      assert_select ".admin-card", text: /Commandes expédiées/
      assert_select ".admin-card", text: /Commandes à traiter\s*2/
      assert_select ".admin-card", text: /Commandes expédiées\s*1/
    end

    test "the 7-day and 30-day period links are available and switch the selected period" do
      sign_in_as(create_admin_user)

      get admin_root_path, params: { period: 7 }

      assert_response :success
      assert_select ".sales-chart-period a.is-active", text: "7 jours"
    end

    test "sidebar links to the existing admin sections" do
      sign_in_as(create_admin_user)

      get admin_root_path

      assert_select "a[href=?]", admin_catalog_variants_path, text: "Édition rapide"
      assert_select "a[href=?]", admin_shipping_configuration_path, text: "Livraison"
      assert_select "a[href=?]", admin_promo_codes_path, text: "Promos"
      assert_select "a[href=?]", admin_reviews_path, text: "Avis"
      assert_select "a[href=?]", admin_seo_path, text: "SEO"
      assert_select "a[href=?]", admin_olfactory_families_path, text: "Familles"
    end
  end
end

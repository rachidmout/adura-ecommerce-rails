require "test_helper"

module Admin
  class CatalogVariantsControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_catalog_variants_path

      assert_redirected_to admin_login_path
    end

    test "filters by product name, SKU, brand, state and low stock" do
      sign_in_as(create_admin_user)
      low_stock = create_publishable_product(slug: "quick-filter-low", stock_quantity: 5)
      inactive = create_publishable_product(slug: "quick-filter-inactive")
      low_variant = low_stock.product_variants.first
      low_variant.update!(reserved_stock_quantity: 2)
      inactive.product_variants.first.update!(active: false)

      get admin_catalog_variants_path, params: { q: low_variant.sku, brand: low_stock.brand_id, status: "active", low_stock: "1" }

      assert_response :success
      assert_select "code", text: low_variant.sku
      assert_select "code", text: inactive.product_variants.first.sku, count: 0
      assert_select "a.admin-nav-link.is-active[aria-current='page'][href=?]", admin_catalog_variants_path
    end

    test "filters variants with a missing shipping weight and allows setting it" do
      sign_in_as(create_admin_user)
      missing_weight = create_publishable_product(slug: "missing-shipping-weight").product_variants.first
      weighted = create_publishable_product(slug: "with-shipping-weight").product_variants.first
      weighted.update!(shipping_weight_grams: 250)

      get admin_catalog_variants_path, params: { missing_weight: "1" }
      assert_select "code", text: missing_weight.sku
      assert_select "code", text: weighted.sku, count: 0

      patch admin_catalog_variant_path(missing_weight), params: { product_variant: { price_euros: "20.00", stock_quantity: 5, active: "1", shipping_weight_grams: 300 } }
      assert_equal 300, missing_weight.reload.shipping_weight_grams
    end

    test "updates price, stock and active without permitting reserved stock" do
      sign_in_as(create_admin_user)
      variant = create_publishable_product(slug: "quick-update-controller").product_variants.first
      variant.update!(reserved_stock_quantity: 2)

      patch admin_catalog_variant_path(variant), params: {
        product_variant: { price_euros: "24.50", stock_quantity: 3, active: "0", reserved_stock_quantity: 0 }
      }

      assert_redirected_to admin_catalog_variants_path
      variant.reload
      assert_equal 2450, variant.price_cents
      assert_equal 3, variant.stock_quantity
      assert_not variant.active?
      assert_equal 2, variant.reserved_stock_quantity
    end

    test "refuses stock below the current reservation" do
      sign_in_as(create_admin_user)
      variant = create_publishable_product(slug: "quick-update-refusal").product_variants.first
      variant.update!(reserved_stock_quantity: 2)

      patch admin_catalog_variant_path(variant), params: { product_variant: { price_euros: "20.00", stock_quantity: 1, active: "1" } }

      assert_redirected_to admin_catalog_variants_path
      assert_match "stock réservé", flash[:alert]
      assert_equal 5, variant.reload.stock_quantity
      assert_equal 2, variant.reserved_stock_quantity
    end

    test "does not change historical order item prices" do
      sign_in_as(create_admin_user)
      variant = create_publishable_product(slug: "quick-update-history", price_cents: 1800).product_variants.first
      order = create_paid_order(variant: variant)
      item = order.order_items.first

      patch admin_catalog_variant_path(variant), params: { product_variant: { price_euros: "25.00", stock_quantity: 5, active: "1" } }

      assert_equal 2500, variant.reload.price_cents
      assert_equal 1800, item.reload.unit_price_cents
      assert_equal 1800, item.line_total_cents
    end
  end
end

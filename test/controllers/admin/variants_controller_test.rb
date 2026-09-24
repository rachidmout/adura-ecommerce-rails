require "test_helper"

module Admin
  class VariantsControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      product = create_publishable_product
      get admin_product_variants_path(product)
      assert_redirected_to admin_login_path
    end

    test "create adds a new variant to the product" do
      sign_in_as(create_admin_user)
      product = create_publishable_product

      assert_difference "product.product_variants.count", 1 do
        post admin_product_variants_path(product), params: {
          product_variant: { sku: "ADURA-TEST-50", volume_ml: 50, price_euros: "15.00", currency: "EUR", stock_quantity: 3, shipping_weight_grams: 280, active: true }
        }
      end
      assert_redirected_to edit_admin_product_path(product)
      assert_equal "ADURA-TEST-50", product.product_variants.find_by!(volume_ml: 50).sku
      assert_equal 280, product.product_variants.find_by!(volume_ml: 50).shipping_weight_grams
    end

    test "create generates a SKU server-side when it is left blank" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(slug: "sku-automatique")

      post admin_product_variants_path(product), params: {
        product_variant: { sku: "", volume_ml: 50, price_euros: "15.00", currency: "EUR", stock_quantity: 0, active: true }
      }

      variant = product.product_variants.find_by!(volume_ml: 50)
      assert_equal "ADURA-SKU-AUTOMATIQUE-50", variant.sku
      assert_equal 0, variant.stock_quantity
      assert_equal 0, variant.reserved_stock_quantity
    end

    test "create generates a unique SKU when the automatic SKU already exists" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(slug: "sku-collision")
      product.product_variants.create!(sku: "ADURA-SKU-COLLISION-50", volume_ml: 50, price_cents: 1_500, stock_quantity: 0, currency: "EUR", active: false)

      post admin_product_variants_path(product), params: {
        product_variant: { sku: "", volume_ml: 50, price_euros: "15.00", currency: "EUR", stock_quantity: 0, active: true }
      }

      assert product.product_variants.exists?(sku: "ADURA-SKU-COLLISION-50-2")
    end

    test "edit renders the form for an existing variant" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      variant = product.product_variants.first
      variant.update!(shipping_weight_grams: 350)

      get edit_admin_product_variant_path(product, variant)

      assert_response :success
      assert_select "input[name='product_variant[price_euros]']"
      assert_select "input[disabled]", count: 2
    end

    test "update converts a euro price into price_cents" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      variant = product.product_variants.first

      patch admin_product_variant_path(product, variant), params: { product_variant: { price_euros: "19.90" } }

      assert_redirected_to edit_admin_product_path(product)
      assert_equal 1990, variant.reload.price_cents
    end

    test "update rejects a non-numeric price and keeps the previous price_cents" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(price_cents: 1800)
      variant = product.product_variants.first

      patch admin_product_variant_path(product, variant), params: { product_variant: { price_euros: "abc" } }

      assert_response :unprocessable_entity
      assert_equal 1800, variant.reload.price_cents
    end

    test "destroy deactivates the variant instead of deleting it" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      variant = product.product_variants.first
      create_paid_order(variant: variant)

      assert_no_difference "ProductVariant.count" do
        delete admin_product_variant_path(product, variant)
      end
      assert_not variant.reload.active?
      assert_match "historique", flash[:notice]
    end

    test "destroy permanently removes a variant without business history" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      variant = product.product_variants.first

      assert_difference "ProductVariant.count", -1 do
        delete admin_product_variant_path(product, variant)
      end
      assert_match "supprimée", flash[:notice]
    end

    test "destroy deactivates a variant with a stock reservation item" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      variant = product.product_variants.first
      payment = create_paid_order.payments.create!(provider: "stripe", status: :succeeded, amount_cents: 2_490, currency: "EUR")
      reservation = payment.create_stock_reservation!(state: :active, expires_at: 30.minutes.from_now)
      reservation.stock_reservation_items.create!(product_variant: variant, quantity: 1)

      assert_no_difference "ProductVariant.count" do
        delete admin_product_variant_path(product, variant)
      end
      assert_not variant.reload.active?
      assert_match "historique", flash[:notice]
    end

    test "update ignores a reserved stock value submitted by the browser" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      variant = product.product_variants.first

      patch admin_product_variant_path(product, variant), params: { product_variant: { stock_quantity: 6, reserved_stock_quantity: 5 } }

      variant.reload
      assert_equal 6, variant.stock_quantity
      assert_equal 0, variant.reserved_stock_quantity
    end

    test "duplicate creates an editable copy with a new SKU and no stock" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(slug: "duplicate-variante", price_cents: 1_800, stock_quantity: 4)
      variant = product.product_variants.first
      variant.update!(shipping_weight_grams: 350)

      assert_difference "ProductVariant.count", 1 do
        post duplicate_admin_product_variant_path(product, variant)
      end

      duplicated = product.product_variants.order(:created_at).last
      assert_redirected_to edit_admin_product_variant_path(product, duplicated)
      assert_equal "ADURA-DUPLICATE-VARIANTE-100", duplicated.sku
      assert_equal variant.volume_ml, duplicated.volume_ml
      assert_equal variant.price_cents, duplicated.price_cents
      assert_equal 0, duplicated.stock_quantity
      assert_equal 0, duplicated.reserved_stock_quantity
      assert_equal 350, duplicated.shipping_weight_grams
    end
  end
end

require "test_helper"

module Admin
  class ProductsControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_products_path
      assert_redirected_to admin_login_path
    end

    test "search filters by product or brand name" do
      sign_in_as(create_admin_user)
      matching = create_publishable_product(slug: "khamrah-test")
      other = create_publishable_product(slug: "yara-test", family_slug: "floral")

      get admin_products_path, params: { q: matching.name }

      assert_response :success
      assert_select "strong", text: matching.name
      assert_select "strong", text: other.name, count: 0
    end

    test "availability filter separates in-stock from out-of-stock products" do
      sign_in_as(create_admin_user)
      in_stock = create_publishable_product(slug: "in-stock-test", stock_quantity: 5)
      out_of_stock = create_publishable_product(slug: "out-of-stock-test", stock_quantity: 0)

      get admin_products_path, params: { availability: "out_of_stock" }

      assert_select "strong", text: in_stock.name, count: 0
      assert_select "strong", text: out_of_stock.name
    end

    test "low stock filter uses the available stock threshold" do
      sign_in_as(create_admin_user)
      low_stock = create_publishable_product(slug: "low-stock-filter-test", stock_quantity: 5)
      regular_stock = create_publishable_product(slug: "regular-stock-filter-test", stock_quantity: 5)
      low_stock.product_variants.first.update!(reserved_stock_quantity: 2)

      get admin_products_path, params: { low_stock: "1" }

      assert_select "strong", text: low_stock.name
      assert_select "strong", text: regular_stock.name, count: 0
      assert_select "label", text: "Stock faible (≤ #{ProductVariant::LOW_STOCK_THRESHOLD})"
    end

    test "catalog rows expose the daily management actions" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(slug: "catalog-actions-test")

      get admin_products_path

      assert_select "a[href=?]", edit_admin_product_path(product), text: "Modifier"
      assert_select "a[href=?]", admin_product_variants_path(product), text: "Variantes"
      assert_select "a[href=?]", product_path(slug: product.slug, locale: nil), text: "Voir"
      assert_select "form[action=?]", duplicate_admin_product_path(product)
    end

    test "duplicates a product and opens its draft edit page" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(slug: "duplicate-controller-test")

      assert_difference "Product.count", 1 do
        post duplicate_admin_product_path(product)
      end

      duplicated = Product.order(:created_at).last
      assert_redirected_to edit_admin_product_path(duplicated)
      assert duplicated.draft?
    end

    test "show redirects to the edit page" do
      sign_in_as(create_admin_user)
      product = create_publishable_product

      get admin_product_path(product)
      assert_redirected_to edit_admin_product_path(product)
    end

    test "updating olfactory notes replaces each layer's notes" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      vanilla = OlfactoryNote.create!(name: "Vanille", slug: "vanille-test")
      bergamot = OlfactoryNote.create!(name: "Bergamote", slug: "bergamote-test")

      patch admin_product_path(product), params: {
        product: {
          name: product.name, slug: product.slug, brand_id: product.brand_id,
          short_description: product.short_description, description: product.description,
          source_urls_text: product.source_urls.join("\n"), top_note_ids: [ bergamot.id ], base_note_ids: [ vanilla.id ]
        }
      }

      assert_redirected_to edit_admin_product_path(product)
      product.reload
      assert_equal [ bergamot ], product.product_olfactory_notes.where(layer: "top").map(&:olfactory_note)
      assert_equal [ vanilla ], product.product_olfactory_notes.where(layer: "base").map(&:olfactory_note)
      assert_empty product.product_olfactory_notes.where(layer: "heart")
    end

    test "destroy archives the product instead of deleting it" do
      sign_in_as(create_admin_user)
      product = create_publishable_product

      assert_no_difference "Product.count" do
        delete admin_product_path(product)
      end
      assert product.reload.archived?
    end
  end
end

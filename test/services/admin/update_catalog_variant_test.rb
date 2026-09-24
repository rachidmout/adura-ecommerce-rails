require "test_helper"

module Admin
  class UpdateCatalogVariantTest < ActiveSupport::TestCase
    test "updates only the allowed catalog fields" do
      variant = create_publishable_product(slug: "quick-edit-allowed").product_variants.first
      variant.update!(reserved_stock_quantity: 2)

      UpdateCatalogVariant.new(
        variant: variant,
        attributes: { price_euros: "19.90", stock_quantity: 3, active: false }
      ).call

      variant.reload
      assert_equal 1990, variant.price_cents
      assert_equal 3, variant.stock_quantity
      assert_not variant.active?
      assert_equal 2, variant.reserved_stock_quantity
    end

    test "refuses stock below the reservation after locking the variant" do
      variant = create_publishable_product(slug: "quick-edit-below-reserved").product_variants.first
      variant.update!(reserved_stock_quantity: 2)

      error = assert_raises(ActiveRecord::RecordInvalid) do
        UpdateCatalogVariant.new(variant: variant, attributes: { stock_quantity: 1 }).call
      end

      assert_match "stock réservé", error.record.errors.full_messages.to_sentence
      assert_equal 5, variant.reload.stock_quantity
      assert_equal 2, variant.reserved_stock_quantity
    end

    test "accepts stock equal to the reservation" do
      variant = create_publishable_product(slug: "quick-edit-equal-reserved").product_variants.first
      variant.update!(reserved_stock_quantity: 2)

      UpdateCatalogVariant.new(variant: variant, attributes: { stock_quantity: 2 }).call

      assert_equal 2, variant.reload.stock_quantity
      assert_equal 2, variant.reserved_stock_quantity
    end

    test "rejects a negative price" do
      variant = create_publishable_product(slug: "quick-edit-negative-price", price_cents: 1800).product_variants.first

      assert_raises(ActiveRecord::RecordInvalid) do
        UpdateCatalogVariant.new(variant: variant, attributes: { price_euros: "-1" }).call
      end

      assert_equal 1800, variant.reload.price_cents
    end
  end
end

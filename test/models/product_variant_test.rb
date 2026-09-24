require "test_helper"

class ProductVariantTest < ActiveSupport::TestCase
  test "availability depends on publication active state and stock" do
    product = create_publishable_product
    variant = product.product_variants.first
    assert variant.available?

    variant.update!(stock_quantity: 0)
    assert_not variant.available?
  end

  test "stock cannot be negative" do
    product = create_publishable_product
    variant = product.product_variants.first
    variant.stock_quantity = -1
    assert_not variant.valid?
  end

  test "shipping weight is optional but must be strictly positive when set" do
    variant = create_publishable_product.product_variants.first

    variant.shipping_weight_grams = nil
    assert variant.valid?

    variant.shipping_weight_grams = 250
    assert variant.valid?

    variant.shipping_weight_grams = 0
    assert_not variant.valid?

    variant.shipping_weight_grams = -1
    assert_not variant.valid?
  end

  test "price_euros reads price_cents as euros when the virtual attribute was not touched" do
    product = create_publishable_product(price_cents: 1800)
    variant = product.product_variants.first
    assert_equal 18.0, variant.price_euros
  end

  test "price_euros= converts a plain integer string to cents" do
    product = create_publishable_product
    variant = product.product_variants.first
    variant.price_euros = "18"
    assert_equal 1800, variant.price_cents
  end

  test "price_euros= converts a two-decimal euro string to cents without float rounding drift" do
    product = create_publishable_product
    variant = product.product_variants.first
    variant.price_euros = "19.90"
    assert_equal 1990, variant.price_cents
  end

  test "price_euros= accepts a comma as decimal separator" do
    product = create_publishable_product
    variant = product.product_variants.first
    variant.price_euros = "19,90"
    assert_equal 1990, variant.price_cents
  end

  test "price_euros= rejects a non-numeric value and leaves price_cents untouched" do
    product = create_publishable_product(price_cents: 1800)
    variant = product.product_variants.first
    variant.price_euros = "abc"

    assert_not variant.valid?
    assert_includes variant.errors[:price_euros], "doit être un nombre positif, par exemple 18.00"
    assert_equal 1800, variant.price_cents
  end

  test "price_euros= rejects a negative value and leaves price_cents untouched" do
    product = create_publishable_product(price_cents: 1800)
    variant = product.product_variants.first
    variant.price_euros = "-5"

    assert_not variant.valid?
    assert_includes variant.errors[:price_euros], "doit être un nombre positif, par exemple 18.00"
    assert_equal 1800, variant.price_cents
  end

  test "setting price_cents directly (seeds, console) never triggers the price_euros validation" do
    product = create_publishable_product
    variant = product.product_variants.first
    variant.price_cents = 2200
    assert variant.valid?
  end

  test "next_sku uses the product slug and adds a suffix on collision" do
    product = create_publishable_product(slug: "khamrah")

    assert_equal "ADURA-KHAMRAH-50", ProductVariant.next_sku(product_slug: product.slug, volume_ml: 50)

    product.product_variants.create!(sku: "ADURA-KHAMRAH-50", volume_ml: 50, price_cents: 1_500, stock_quantity: 0, currency: "EUR", active: false)
    assert_equal "ADURA-KHAMRAH-50-2", ProductVariant.next_sku(product_slug: product.slug, volume_ml: 50)
  end
end

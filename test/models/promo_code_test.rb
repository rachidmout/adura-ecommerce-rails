require "test_helper"

class PromoCodeTest < ActiveSupport::TestCase
  test "discount_for computes a percentage discount of the subtotal" do
    promo_code = create_promo_code(discount_type: :percentage, discount_value: 20)

    assert_equal 400, promo_code.discount_for(2_000)
  end

  test "discount_for on a fixed amount code never exceeds the subtotal" do
    promo_code = create_promo_code(discount_type: :fixed_amount, discount_value: 1_000)

    assert_equal 1_000, promo_code.discount_for(5_000)
    assert_equal 500, promo_code.discount_for(500), "a 10€ fixed discount on a 5€ order should cap at 5€, never go negative"
  end

  test "active_now excludes inactive, not-yet-started and expired codes" do
    active = create_promo_code(code: "ACTIVE1")
    inactive = create_promo_code(code: "INACTIVE1", active: false)
    future = create_promo_code(code: "FUTURE1", starts_at: 1.day.from_now)
    expired = create_promo_code(code: "EXPIRED1", ends_at: 1.day.ago)

    assert_includes PromoCode.active_now, active
    assert_not_includes PromoCode.active_now, inactive
    assert_not_includes PromoCode.active_now, future
    assert_not_includes PromoCode.active_now, expired
  end

  test "percentage discount_value cannot exceed 100" do
    promo_code = PromoCode.new(code: "TOOMUCH", discount_type: "percentage", discount_value: 150)

    assert_not promo_code.valid?
  end

  test "applies_to_product_id? is unscoped by default and scoped once a product or family is attached" do
    promo_code = create_promo_code
    product = create_publishable_product(slug: "scoped-product-test")
    other_product = create_publishable_product(slug: "other-product-test")

    assert promo_code.applies_to_product_id?(product.id), "an unscoped code applies to every product"

    promo_code.promo_code_products.create!(product: product)

    assert promo_code.applies_to_product_id?(product.id)
    assert_not promo_code.applies_to_product_id?(other_product.id)
  end

  test "uses_count and revenue_generated_cents only count completed orders that used the code" do
    promo_code = create_promo_code
    variant = create_publishable_product(slug: "promo-usage-test").product_variants.first

    paid_order = create_paid_order(variant: variant, status: :paid)
    paid_order.update!(promo_code: promo_code, discount_cents: 200, subtotal_cents: paid_order.subtotal_cents, shipping_cents: paid_order.shipping_cents, total_cents: paid_order.subtotal_cents + paid_order.shipping_cents - 200)

    pending_order = create_paid_order(variant: variant, status: :pending)
    pending_order.update!(promo_code: promo_code)

    assert_equal 1, promo_code.uses_count
    assert_equal paid_order.total_cents, promo_code.revenue_generated_cents
    assert_equal 200, promo_code.discount_given_cents
  end
end

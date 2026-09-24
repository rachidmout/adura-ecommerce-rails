require "test_helper"

class PromotionsApplyPromoCodeTest < ActiveSupport::TestCase
  test "a valid code succeeds and returns the computed discount" do
    create_promo_code(code: "VALID10", discount_type: :percentage, discount_value: 10)

    result = Promotions::ApplyPromoCode.new(code: "valid10", subtotal_cents: 2_000, product_ids: []).call

    assert result.success?
    assert_equal 200, result.discount_cents
  end

  test "an expired code is rejected" do
    create_promo_code(code: "EXPIRED1", ends_at: 1.day.ago)

    result = Promotions::ApplyPromoCode.new(code: "EXPIRED1", subtotal_cents: 2_000, product_ids: []).call

    assert_not result.success?
    assert_equal 0, result.discount_cents
  end

  test "a disabled code is rejected" do
    create_promo_code(code: "DISABLED1", active: false)

    result = Promotions::ApplyPromoCode.new(code: "DISABLED1", subtotal_cents: 2_000, product_ids: []).call

    assert_not result.success?
  end

  test "a code that already reached its global usage limit is rejected" do
    promo_code = create_promo_code(code: "MAXED1", max_uses: 1)
    variant = create_publishable_product(slug: "maxed-promo-test").product_variants.first
    used_order = create_paid_order(variant: variant, status: :paid)
    used_order.update!(promo_code: promo_code)

    result = Promotions::ApplyPromoCode.new(code: "MAXED1", subtotal_cents: 2_000, product_ids: []).call

    assert_not result.success?
  end

  test "a code that already reached its per-customer usage limit is rejected for that customer" do
    promo_code = create_promo_code(code: "ONEPERCUSTOMER", max_uses_per_customer: 1)
    variant = create_publishable_product(slug: "per-customer-promo-test").product_variants.first
    used_order = create_paid_order(variant: variant, status: :paid)
    used_order.update!(promo_code: promo_code, email: "repeat.customer@example.com")

    result = Promotions::ApplyPromoCode.new(code: "ONEPERCUSTOMER", subtotal_cents: 2_000, product_ids: [], email: "repeat.customer@example.com").call
    other_customer_result = Promotions::ApplyPromoCode.new(code: "ONEPERCUSTOMER", subtotal_cents: 2_000, product_ids: [], email: "someone.else@example.com").call

    assert_not result.success?
    assert other_customer_result.success?
  end

  test "a code below its minimum order amount is rejected" do
    create_promo_code(code: "MIN50", min_order_cents: 5_000)

    result = Promotions::ApplyPromoCode.new(code: "MIN50", subtotal_cents: 2_000, product_ids: []).call

    assert_not result.success?
  end

  test "public promo errors are localized in Dutch" do
    create_promo_code(code: "NL-MINIMUM", min_order_cents: 5_000)

    result = I18n.with_locale(:nl) do
      Promotions::ApplyPromoCode.new(code: "NL-MINIMUM", subtotal_cents: 2_000, product_ids: []).call
    end

    assert_equal "Voor deze code geldt een minimumbedrag van € 50,00.", result.error_message
  end

  test "a product-scoped code is rejected when the cart doesn't contain that product" do
    promo_code = create_promo_code(code: "SCOPEDPROD")
    scoped_product = create_publishable_product(slug: "scoped-promo-product")
    other_product = create_publishable_product(slug: "unscoped-promo-product")
    promo_code.promo_code_products.create!(product: scoped_product)

    matching = Promotions::ApplyPromoCode.new(code: "SCOPEDPROD", subtotal_cents: 2_000, product_ids: [ scoped_product.id ]).call
    not_matching = Promotions::ApplyPromoCode.new(code: "SCOPEDPROD", subtotal_cents: 2_000, product_ids: [ other_product.id ]).call

    assert matching.success?
    assert_not not_matching.success?
  end

  test "an unknown code is rejected" do
    result = Promotions::ApplyPromoCode.new(code: "DOESNOTEXIST", subtotal_cents: 2_000, product_ids: []).call

    assert_not result.success?
    assert result.error_message.present?
  end
end

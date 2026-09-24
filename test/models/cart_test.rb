require "test_helper"

class CartTest < ActiveSupport::TestCase
  test "adds a variant and recalculates the server-side subtotal" do
    product = create_publishable_product(price_cents: 1_800, stock_quantity: 3)
    cart = Cart.new({})
    cart.add(product.product_variants.first.id, 2)

    assert_equal 2, cart.count
    assert_equal 3_600, cart.subtotal_cents
  end

  test "caps quantity at available stock" do
    product = create_publishable_product(stock_quantity: 2)
    cart = Cart.new({})
    cart.add(product.product_variants.first.id, 10)
    assert_equal 2, cart.count
  end

  test "does not add a fully reserved variant" do
    product = create_publishable_product(stock_quantity: 1)
    variant = product.product_variants.first
    variant.update!(reserved_stock_quantity: 1)

    assert_raises(Cart::UnavailableVariant) { Cart.new({}).add(variant.id) }
  end
end

require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "in_stock and out_of_stock partition products by active variant stock" do
    in_stock = create_publishable_product(slug: "in-stock-model-test", stock_quantity: 4)
    out_of_stock = create_publishable_product(slug: "out-of-stock-model-test", stock_quantity: 0)

    assert_includes Product.in_stock, in_stock
    assert_not_includes Product.in_stock, out_of_stock

    assert_includes Product.out_of_stock, out_of_stock
    assert_not_includes Product.out_of_stock, in_stock
  end
end

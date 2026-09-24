require "test_helper"

class ShopSettingTest < ActiveSupport::TestCase
  test "applies fixed shipping below the threshold" do
    setting = ShopSetting.new(code: "test", shipping_rate_cents: 490, free_shipping_threshold_cents: 5_000)
    assert_equal 490, setting.shipping_for(4_999)
  end

  test "offers shipping at the configured threshold" do
    setting = ShopSetting.new(code: "test", shipping_rate_cents: 490, free_shipping_threshold_cents: 5_000)
    assert_equal 0, setting.shipping_for(5_000)
  end

  test "base packaging weight is optional but must be strictly positive when set" do
    setting = ShopSetting.new(code: "packaging-test")

    setting.base_packaging_weight_grams = nil
    assert setting.valid?

    setting.base_packaging_weight_grams = 120
    assert setting.valid?

    setting.base_packaging_weight_grams = 0
    assert_not setting.valid?

    setting.base_packaging_weight_grams = -1
    assert_not setting.valid?
  end
end

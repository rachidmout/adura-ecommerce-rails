require "test_helper"

class ShippingRateTest < ActiveSupport::TestCase
  setup do
    zone = ShippingZone.create!(name: "France")
    @method = zone.shipping_methods.create!(name: "Standard", carrier_name: "Colissimo")
  end

  test "accepts valid bounded and open-ended weight bands" do
    bounded = @method.shipping_rates.create!(min_weight_grams: 0, max_weight_grams: 500, price_cents: 490)
    open_ended = @method.shipping_rates.new(min_weight_grams: 501, max_weight_grams: nil, price_cents: 690)

    assert bounded.persisted?
    assert open_ended.valid?
  end

  test "rejects invalid bounds and negative prices" do
    rate = @method.shipping_rates.new(min_weight_grams: -1, max_weight_grams: 100, price_cents: 490)
    assert_not rate.valid?

    rate.min_weight_grams = 100
    rate.max_weight_grams = 100
    assert_not rate.valid?

    rate.max_weight_grams = nil
    rate.price_cents = -1
    assert_not rate.valid?
  end

  test "rejects overlapping bands, including inactive bands" do
    @method.shipping_rates.create!(min_weight_grams: 0, max_weight_grams: 500, price_cents: 490, active: false)
    overlapping = @method.shipping_rates.new(min_weight_grams: 500, max_weight_grams: 1_000, price_cents: 690)

    assert_not overlapping.valid?
    assert_includes overlapping.errors[:base], "chevauche une tranche existante"
  end
end

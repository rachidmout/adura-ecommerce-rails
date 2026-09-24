require "test_helper"

class ShippingMethodTest < ActiveSupport::TestCase
  setup do
    @zone = ShippingZone.create!(name: "France")
  end

  test "requires a name and carrier name" do
    method = ShippingMethod.new(shipping_zone: @zone)

    assert_not method.valid?
    assert method.errors.added?(:name, :blank)
    assert method.errors.added?(:carrier_name, :blank)
  end

  test "allows an optional non-negative free shipping threshold" do
    method = ShippingMethod.new(shipping_zone: @zone, name: "Standard", carrier_name: "Colissimo")
    assert method.valid?

    method.free_shipping_threshold_cents = 0
    assert method.valid?

    method.free_shipping_threshold_cents = -1
    assert_not method.valid?
  end

  test "supports a pickup point method while rejecting an unknown kind" do
    method = ShippingMethod.new(shipping_zone: @zone, name: "Point relais", carrier_name: "Mondial Relay", kind: "pickup_point")

    assert method.valid?
    assert method.pickup_point?
    assert_not method.home_delivery?

    method.kind = "unknown"
    assert_not method.valid?
  end

  test "requires a stable Sendcloud carrier code while allowing an optional method override" do
    method = ShippingMethod.new(shipping_zone: @zone, name: "Relais Sendcloud", carrier_name: "Mondial Relay", kind: "pickup_point", provider: "sendcloud")

    assert_not method.valid?
    assert method.errors.added?(:provider_carrier_code, :blank)

    method.provider_carrier_code = "mondial_relay"
    assert_predicate method, :valid?

    method.provider_method_id_override = "8"
    assert_predicate method, :valid?

    method.provider_method_id_override = "service-relay"
    assert_not method.valid?
    assert_includes method.errors[:provider_method_id_override], "doit être un identifiant Sendcloud numérique positif"
  end

  test "cannot be destroyed while it has rates" do
    method = ShippingMethod.create!(shipping_zone: @zone, name: "Standard", carrier_name: "Colissimo")
    method.shipping_rates.create!(min_weight_grams: 0, price_cents: 490)

    assert_not method.destroy
    assert_not_empty method.errors[:base]
  end
end

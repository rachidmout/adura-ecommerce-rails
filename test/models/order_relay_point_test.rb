require "test_helper"

class OrderRelayPointTest < ActiveSupport::TestCase
  test "requires a complete, country-normalized relay snapshot" do
    relay_point = OrderRelayPoint.new(
      order: create_paid_order,
      carrier: "Mondial Relay", relay_id: "MR-75001-001", relay_name: "Relais Paris",
      relay_address_line1: "1 rue de Test", relay_postal_code: "75001", relay_city: "Paris", relay_country: "fr"
    )

    assert relay_point.valid?
    assert_equal "FR", relay_point.relay_country
  end

  test "rejects an incomplete relay snapshot" do
    relay_point = OrderRelayPoint.new(order: create_paid_order, carrier: "Mondial Relay", relay_id: "MR-1")

    assert_not relay_point.valid?
    assert_includes relay_point.errors.attribute_names, :relay_name
    assert_includes relay_point.errors.attribute_names, :relay_country
  end
end

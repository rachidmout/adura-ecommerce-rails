require "test_helper"

class ShipmentTest < ActiveSupport::TestCase
  test "a shipment belongs to one order and validates its lifecycle" do
    shipment = Shipment.new(order: create_paid_order, carrier: "Mondial Relay", service: "Point Relais", status: :pending)

    assert_predicate shipment, :valid?
    assert_not_predicate Shipment.new(order: create_paid_order, carrier: "", service: "Point Relais"), :valid?
    assert_not_predicate Shipment.new(order: create_paid_order, carrier: "Mondial Relay", service: ""), :valid?
  end

  test "a ready shipment requires carrier and tracking references" do
    shipment = Shipment.new(order: create_paid_order, carrier: "Mondial Relay", service: "Point Relais", status: :created)

    assert_not_predicate shipment, :valid?
    assert_not_empty shipment.errors[:carrier_shipment_id]
    assert_not_empty shipment.errors[:tracking_number]
  end

  test "only one shipment can be attached to an order" do
    order = create_paid_order
    Shipment.create!(order: order, carrier: "Mondial Relay", service: "Point Relais", status: :failed, error_message: "Indisponible")

    duplicate = Shipment.new(order: order, carrier: "Mondial Relay", service: "Point Relais", status: :failed, error_message: "Indisponible")

    assert_not_predicate duplicate, :valid?
    assert duplicate.errors.of_kind?(:order_id, :taken)
  end
end

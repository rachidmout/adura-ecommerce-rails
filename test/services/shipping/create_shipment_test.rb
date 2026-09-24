require "test_helper"

class Shipping::CreateShipmentTest < ActiveSupport::TestCase
  class FailingClient < Shipping::Carriers::BaseShipmentClient
    def create(order:)
      raise Unavailable, "Le transporteur est indisponible."
    end
  end

  test "creates a label-ready fake shipment for a paid home-delivery order" do
    order = create_paid_order(status: :paid)
    order.update!(shipping_carrier_name: "Colissimo / La Poste", shipping_method_name: "Livraison standard")

    shipment = Shipping::CreateShipment.new(order: order, client: Shipping::Carriers::FakeShipmentClient.new).call

    assert_equal shipment, order.reload.shipment
    assert_predicate shipment, :label_ready?
    assert_equal "Colissimo / La Poste", shipment.carrier
    assert shipment.carrier_shipment_id.present?
    assert shipment.tracking_number.present?
    assert_predicate shipment.label, :attached?
    assert_equal "home_delivery", shipment.raw_response.fetch("destination_type")
    assert order.paid?
  end

  test "uses the saved relay snapshot rather than the customer address for a pickup-point shipment" do
    order = create_paid_order(status: :paid)
    order.update!(shipping_carrier_name: "Mondial Relay", shipping_method_name: "Point Relais")
    order.create_relay_point!(
      carrier: "Mondial Relay", relay_id: "MR-75001-001", relay_name: "Relais Paris",
      relay_address_line1: "1 rue de Test", relay_postal_code: "75001", relay_city: "Paris", relay_country: "FR"
    )

    shipment = Shipping::CreateShipment.new(order: order, client: Shipping::Carriers::FakeShipmentClient.new).call

    assert_equal "pickup_point", shipment.raw_response.fetch("destination_type")
    assert_equal "MR-75001-001", shipment.raw_response.fetch("relay_id")
  end

  test "refuses a non-paid order without creating a shipment" do
    order = create_paid_order(status: :pending)

    assert_raises(Shipping::CreateShipment::InvalidOrder) do
      Shipping::CreateShipment.new(order: order, client: Shipping::Carriers::FakeShipmentClient.new).call
    end

    assert_nil order.reload.shipment
  end

  test "stores a carrier failure and allows the same shipment to be retried" do
    order = create_paid_order(status: :paid)

    error = assert_raises(Shipping::CreateShipment::Unavailable) do
      Shipping::CreateShipment.new(order: order, client: FailingClient.new).call
    end

    assert_equal "Le transporteur est indisponible.", error.message
    failed = order.reload.shipment
    assert_predicate failed, :failed?
    assert_equal "Le transporteur est indisponible.", failed.error_message

    retried = Shipping::CreateShipment.new(order: order, client: Shipping::Carriers::FakeShipmentClient.new).call

    assert_equal failed.id, retried.id
    assert_predicate retried, :label_ready?
    assert_nil retried.error_message
  end

  test "does not create a second carrier shipment when one is already ready" do
    order = create_paid_order(status: :paid)
    Shipping::CreateShipment.new(order: order, client: Shipping::Carriers::FakeShipmentClient.new).call

    assert_raises(Shipping::CreateShipment::AlreadyCreated) do
      Shipping::CreateShipment.new(order: order, client: Shipping::Carriers::FakeShipmentClient.new).call
    end

    assert_equal 1, Shipment.where(order: order).count
  end
end

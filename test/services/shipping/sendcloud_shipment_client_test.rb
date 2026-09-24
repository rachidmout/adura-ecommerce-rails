require "test_helper"

class Shipping::Carriers::SendcloudShipmentClientTest < ActiveSupport::TestCase
  class StubApi
    attr_reader :panel_base_url, :payload, :calls

    def initialize(pickup_methods: [ { "id" => 8, "carrier" => "mondial_relay", "min_weight" => "0.001", "max_weight" => "20" } ], home_methods: [ { "id" => 12, "shipping_product_code" => "colissimo:home", "properties" => { "min_weight" => 1, "max_weight" => 20_000 } } ])
      @panel_base_url = URI("https://panel.sendcloud.sc/api/v2")
      @pickup_methods = pickup_methods
      @home_methods = home_methods
      @calls = []
    end

    def get_json(_base_url, path, params: {})
      calls << [ path, params ]
      return { "shipping_methods" => @pickup_methods } if path == "/shipping_methods"
      return [ { "methods" => @home_methods } ] if path == "/shipping-products"

      raise "unexpected lookup path"
    end

    def post_json(_base_url, path, payload:)
      @payload = payload
      raise "unexpected path" unless path == "/parcels"

      { "parcel" => { "id" => 123, "tracking_number" => "SC123", "tracking_url" => "https://tracking.example.test/SC123", "label" => "/api/v2/labels/123" } }
    end

    def get_pdf(_base_url, path)
      raise "unexpected label path" unless path == "/api/v2/labels/123"

      "%PDF-1.4\nSendcloud test"
    end
  end

  test "resolves a fresh compatible Sendcloud method for a pickup point" do
    order = create_paid_order(status: :paid)
    order.update!(shipping_carrier_name: "Mondial Relay", shipping_method_name: "Point Relais", shipping_method_kind: "pickup_point", shipping_weight_grams: 200)
    order.create_relay_point!(carrier: "Mondial Relay", relay_id: "123456", relay_name: "Relais ADURA", relay_address_line1: "12 rue du Marché", relay_postal_code: "75001", relay_city: "Paris", relay_country: "FR")
    api = StubApi.new

    result = Shipping::Carriers::SendcloudShipmentClient.new(carrier_code: "mondial_relay", delivery_kind: "pickup_point", client: api).create(order: order)

    assert_equal "123", result.carrier_shipment_id
    assert_equal "SC123", result.tracking_number
    assert_equal "%PDF-1.4\nSendcloud test", result.label_data
    assert_equal 8, api.payload.fetch(:parcel).fetch(:shipment).fetch(:id)
    assert_equal 123_456, api.payload.fetch(:parcel).fetch(:to_service_point)
    assert_includes api.calls, [ "/shipping_methods", { service_point_id: "123456" } ]
    assert_equal 8, result.raw_response.fetch("shipping_method_id")
  end

  test "refuses an override no longer returned as compatible by Sendcloud" do
    order = create_paid_order(status: :paid)
    order.update!(shipping_method_kind: "pickup_point", shipping_weight_grams: 200)
    order.create_relay_point!(carrier: "Mondial Relay", relay_id: "123456", relay_name: "Relais ADURA", relay_address_line1: "12 rue du Marché", relay_postal_code: "75001", relay_city: "Paris", relay_country: "FR")

    error = assert_raises(Shipping::Carriers::BaseShipmentClient::Unavailable) do
      Shipping::Carriers::SendcloudShipmentClient.new(carrier_code: "mondial_relay", delivery_kind: "pickup_point", method_id_override: "9", client: StubApi.new).create(order: order)
    end

    assert_match "préférence", error.message
  end

  test "resolves a fresh home-delivery method from destination, weight and carrier" do
    order = create_paid_order(status: :paid)
    order.update!(shipping_carrier_name: "Colissimo / La Poste", shipping_method_name: "Domicile", shipping_method_kind: "home_delivery", shipping_weight_grams: 200)
    api = StubApi.new

    result = Shipping::Carriers::SendcloudShipmentClient.new(carrier_code: "colissimo", delivery_kind: "home_delivery", client: api).create(order: order)

    assert_equal 12, api.payload.fetch(:parcel).fetch(:shipment).fetch(:id)
    assert_not api.payload.fetch(:parcel).key?(:to_service_point)
    lookup_params = api.calls.find { |path, _params| path == "/shipping-products" }&.last
    assert_equal "FR", lookup_params.fetch(:from_country)
    assert_equal "FR", lookup_params.fetch(:to_country)
    assert_equal "colissimo", lookup_params.fetch(:carrier)
    assert_equal 200, lookup_params.fetch(:weight)
    assert_equal "gram", lookup_params.fetch(:weight_unit)
    assert_equal "home_delivery", lookup_params.fetch(:last_mile)
    assert_equal 12, result.raw_response.fetch("shipping_method_id")
  end
end

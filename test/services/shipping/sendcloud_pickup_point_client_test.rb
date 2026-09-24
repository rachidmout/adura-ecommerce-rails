require "test_helper"

class Shipping::Carriers::SendcloudPickupPointClientTest < ActiveSupport::TestCase
  class StubApi
    attr_reader :panel_base_url, :service_points_base_url, :calls

    def initialize
      @panel_base_url = URI("https://panel.sendcloud.sc/api/v2")
      @service_points_base_url = URI("https://servicepoints.sendcloud.sc/api/v2")
      @calls = []
    end

    def get_json(_base_url, path, params: {})
      calls << [ path, params ]
      return service_point if path == "/service-points/123456"
      [ service_point ]
    end

    private

    def service_point
      {
        "id" => 123_456,
        "name" => "Relais ADURA",
        "street" => "12 rue du Marché",
        "house_number" => "4",
        "postal_code" => "75001",
        "city" => "Paris",
        "country" => "FR",
        "carrier" => "mondial_relay",
        "distance" => 450,
        "formatted_opening_times" => { "0" => [ "09:00 - 18:00" ] }
      }
    end
  end

  test "maps Sendcloud service points into the existing pickup point contract" do
    api = StubApi.new
    client = Shipping::Carriers::SendcloudPickupPointClient.new(carrier_name: "Mondial Relay", carrier_code: "mondial_relay", client: api)

    point = client.search(postal_code: "75001", city: "Paris", country_code: "FR", package_weight_grams: 200, limit: 5).first

    assert_equal "Mondial Relay", point.carrier
    assert_equal "123456", point.relay_id
    assert_equal "12 rue du Marché 4", point.address_line1
    assert_equal 0.45, point.distance_km
    assert_equal "sendcloud", point.raw_data.fetch("source")
    assert_equal [ "/service-points/", { country: "FR", address: "75001", radius: 5_000, carrier: "mondial_relay" } ], api.calls.first
  end

  test "returns no points without treating a valid empty Sendcloud response as an outage" do
    api = StubApi.new
    api.define_singleton_method(:get_json) { |_base_url, _path, params: {}| calls << [ "/service-points", params ]; [] }
    client = Shipping::Carriers::SendcloudPickupPointClient.new(carrier_name: "Mondial Relay", carrier_code: "mondial_relay", client: api)

    assert_empty client.search(postal_code: "75001", city: "Paris", country_code: "FR", package_weight_grams: 200, limit: 5)
  end

  test "rejects an unexpected Sendcloud payload instead of treating it as an empty result" do
    api = StubApi.new
    api.define_singleton_method(:get_json) { |_base_url, _path, params: {}| calls << [ "/service-points", params ]; { "points" => [] } }
    client = Shipping::Carriers::SendcloudPickupPointClient.new(carrier_name: "Mondial Relay", carrier_code: "mondial_relay", client: api)

    error = assert_raises(Shipping::Carriers::BasePickupPointClient::Unavailable) do
      client.search(postal_code: "75001", city: "Paris", country_code: "FR", package_weight_grams: 200, limit: 5)
    end
    assert_equal "Sendcloud a retourné une réponse invalide.", error.message
  end

  test "retrieves the selected Sendcloud point without caching a shipping method id" do
    api = StubApi.new
    client = Shipping::Carriers::SendcloudPickupPointClient.new(carrier_name: "Mondial Relay", carrier_code: "mondial_relay", client: api)

    point = client.find(relay_id: "123456", country_code: "FR", package_weight_grams: 200)

    assert_equal "123456", point.relay_id
    assert_not_includes api.calls.map(&:first), "/shipping_methods"
  end
end

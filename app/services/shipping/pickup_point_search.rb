module Shipping
  class PickupPointSearch
    class Error < StandardError; end
    class Unavailable < Error; end
    class NotFound < Error; end

    def initialize(provider: "direct", provider_carrier_code: nil, carrier_name:, country_code:, postal_code: nil, city: nil, package_weight_grams:, client: nil)
      @provider = provider.to_s.strip.presence || "direct"
      @provider_carrier_code = provider_carrier_code.to_s.strip.downcase
      @carrier_name = carrier_name.to_s.strip
      @country_code = country_code.to_s.strip.upcase
      @postal_code = postal_code.to_s.strip
      @city = city.to_s.strip
      @package_weight_grams = package_weight_grams.to_i
      @client = client
    end

    def search(limit: 5)
      client.search(postal_code:, city:, country_code:, package_weight_grams:, limit: [ limit.to_i, 5 ].min)
    rescue Carriers::BasePickupPointClient::Unavailable => error
      raise Unavailable, error.message
    end

    def find(relay_id)
      client.find(relay_id: relay_id.to_s.strip, country_code:, package_weight_grams:)
    rescue Carriers::BasePickupPointClient::NotFound => error
      raise NotFound, error.message
    rescue Carriers::BasePickupPointClient::Unavailable => error
      raise Unavailable, error.message
    end

    private

    attr_reader :provider, :provider_carrier_code, :carrier_name, :country_code, :postal_code, :city, :package_weight_grams

    def client
      return @client if @client
      return sendcloud_client if provider == "sendcloud"
      return direct_mondial_relay_client if provider == "direct" && carrier_name == "Mondial Relay"

      raise Unavailable, "Ce transporteur ne propose pas encore de recherche de point relais."
    end

    def sendcloud_client
      if Carriers::SendcloudPickupPointClient.configured?
        Carriers::SendcloudPickupPointClient.new(carrier_name:, carrier_code: provider_carrier_code)
      elsif Rails.env.production?
        raise Unavailable, "Le service de points relais Sendcloud est temporairement indisponible."
      else
        Carriers::FakePickupPointClient.new
      end
    end

    def direct_mondial_relay_client
      if Carriers::MondialRelayPickupPointClient.configured?
        Carriers::MondialRelayPickupPointClient.new
      elsif Rails.env.production?
        raise Unavailable, "Le service de points relais est temporairement indisponible."
      else
        Carriers::FakePickupPointClient.new
      end
    end
  end
end

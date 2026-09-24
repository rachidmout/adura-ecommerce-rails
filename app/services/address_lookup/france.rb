require "json"
require "net/http"

module AddressLookup
  class France
    API_URI = URI("https://geo.api.gouv.fr/communes")
    CACHE_TTL = 12.hours
    TIMEOUT_SECONDS = 2

    def self.cities_for(postal_code)
      new(postal_code).cities
    end

    def initialize(postal_code)
      @postal_code = postal_code.to_s
    end

    def cities
      return [] unless postal_code.match?(/\A\d{5}\z/)

      Rails.cache.fetch([ "address_lookup", "france", postal_code ], expires_in: CACHE_TTL) { fetch_cities }
    rescue StandardError => error
      Rails.logger.info("Recherche de commune indisponible pour #{postal_code}: #{error.class}")
      []
    end

    private

    attr_reader :postal_code

    def fetch_cities
      uri = API_URI.dup
      uri.query = URI.encode_www_form(codePostal: postal_code, fields: "nom", format: "json")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
        http.get(uri.request_uri)
      end
      return [] unless response.code.to_i.between?(200, 299)

      JSON.parse(response.body).filter_map { |commune| commune["nom"].to_s.strip.presence }.uniq.sort
    rescue JSON::ParserError
      []
    end
  end
end

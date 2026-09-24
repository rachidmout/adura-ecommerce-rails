require "digest"
require "net/http"
require "rexml/document"
require "rexml/xpath"

module Shipping
  module Carriers
    class MondialRelayPickupPointClient < BasePickupPointClient
      ENDPOINT = URI("https://api.mondialrelay.fr/Web_Services.asmx").freeze
      SOAP_ACTION = "http://www.mondialrelay.fr/webservice/WSI4_PointRelais_Recherche".freeze
      CARRIER = "Mondial Relay".freeze

      def self.configured?
        ENV["MONDIAL_RELAY_BRAND_CODE"].present? && ENV["MONDIAL_RELAY_PRIVATE_KEY"].present?
      end

      def initialize(brand_code: ENV["MONDIAL_RELAY_BRAND_CODE"], private_key: ENV["MONDIAL_RELAY_PRIVATE_KEY"], country: ENV.fetch("MONDIAL_RELAY_COUNTRY", "FR"))
        @brand_code = brand_code.to_s.strip
        @private_key = private_key.to_s.strip
        @country = country.to_s.strip.upcase
      end

      def search(postal_code:, city:, country_code:, package_weight_grams:, limit:)
        response_points(
          postal_code: postal_code,
          city: city,
          country_code: country_code,
          package_weight_grams: package_weight_grams,
          limit: limit
        )
      end

      def find(relay_id:, country_code:, package_weight_grams:)
        points = response_points(
          relay_id: relay_id,
          country_code: country_code,
          package_weight_grams: package_weight_grams,
          limit: 1
        )
        points.find { |point| point.relay_id == relay_id } || raise(NotFound, "Le point relais sélectionné n’est plus disponible.")
      end

      private

      attr_reader :brand_code, :private_key, :country

      def response_points(relay_id: "", postal_code: "", city: "", country_code:, package_weight_grams:, limit:)
        ensure_configured!
        raise Unavailable, "La recherche de point relais est disponible pour la France uniquement." unless country_code == country && country == "FR"

        values = request_values(relay_id:, postal_code:, city:, package_weight_grams:, limit:)
        response = post_soap(values)
        parse_points(response.body)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError => error
        Rails.logger.warn("Mondial Relay indisponible: #{error.class}")
        raise Unavailable, "Le service de points relais est momentanément indisponible."
      end

      def ensure_configured!
        return if brand_code.present? && private_key.present?

        raise Unavailable, "Le service de points relais est temporairement indisponible."
      end

      def request_values(relay_id:, postal_code:, city:, package_weight_grams:, limit:)
        values = {
          "Enseigne" => brand_code,
          "Pays" => country,
          "NumPointRelais" => relay_id.to_s,
          "Ville" => city.to_s,
          "CP" => postal_code.to_s,
          "Latitude" => "",
          "Longitude" => "",
          "Taille" => "",
          "Poids" => package_weight_grams.to_i.to_s,
          "Action" => "24R",
          "DelaiEnvoi" => "",
          "RayonRecherche" => "",
          "TypeActivite" => "",
          "NACE" => "",
          "NombreResultats" => [ limit.to_i, 5 ].min.to_s
        }
        values["Security"] = Digest::MD5.hexdigest((values.values.join + private_key).upcase)
        values
      end

      def post_soap(values)
        request = Net::HTTP::Post.new(ENDPOINT.request_uri)
        request["Content-Type"] = "text/xml; charset=utf-8"
        request["SOAPAction"] = SOAP_ACTION
        request.body = soap_envelope(values)

        response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 4, read_timeout: 6) { |http| http.request(request) }
        raise Unavailable, "Le service de points relais est momentanément indisponible." unless response.is_a?(Net::HTTPSuccess)

        response
      end

      def soap_envelope(values)
        fields = values.map { |name, value| "<#{name}>#{ERB::Util.html_escape(value)}</#{name}>" }.join
        %(<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><WSI4_PointRelais_Recherche xmlns="http://www.mondialrelay.fr/webservice/">#{fields}</WSI4_PointRelais_Recherche></soap:Body></soap:Envelope>)
      end

      def parse_points(xml)
        document = REXML::Document.new(xml)
        points = REXML::XPath.match(document, "//*[local-name()='PointRelais_Details']").filter_map { |element| pickup_point_from(element) }
        raise Unavailable, "Aucun point relais n’est disponible autour de cette adresse." if points.empty?

        points
      rescue REXML::ParseException
        raise Unavailable, "Le service de points relais est momentanément indisponible."
      end

      def pickup_point_from(element)
        data = element.elements.each_with_object({}) { |child, result| result[child.name] = child.text.to_s.strip.presence }
        return unless data["STAT"].to_s == "0" && data["Num"].present?

        PickupPoint.new(
          CARRIER,
          data.fetch("Num"),
          data["LgAdr1"].presence || "Point Relais",
          data["LgAdr2"].presence || data.fetch("LgAdr1"),
          [ data["LgAdr3"], data["LgAdr4"] ].compact_blank.join(" · ").presence,
          data.fetch("CP"),
          data.fetch("Ville"),
          data.fetch("Pays").to_s.upcase,
          opening_hours(data),
          data["Distance"].to_s.tr(",", ".").to_f.presence,
          data.except("STAT")
        )
      end

      def opening_hours(data)
        days = %w[Lundi Mardi Mercredi Jeudi Vendredi Samedi Dimanche]
        days.filter_map { |day| value = data["Horaires_#{day}"].presence; "#{day}: #{value}" if value }.join(" · ").presence
      end
    end
  end
end

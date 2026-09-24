require "digest"
require "net/http"
require "rexml/document"
require "rexml/xpath"
require "uri"

module Shipping
  module Carriers
    class MondialRelayShipmentClient < BaseShipmentClient
      ENDPOINT = URI("https://api.mondialrelay.fr/WebService.asmx").freeze
      SOAP_ACTION = "http://www.mondialrelay.fr/webservice/WSI2_CreationEtiquette".freeze
      CARRIER = "Mondial Relay".freeze
      LABEL_HOSTS = %w[api.mondialrelay.fr www.mondialrelay.fr].freeze
      REQUIRED_ENV = %w[
        MONDIAL_RELAY_BRAND_CODE
        MONDIAL_RELAY_PRIVATE_KEY
        MONDIAL_RELAY_SENDER_NAME
        MONDIAL_RELAY_SENDER_ADDRESS_LINE1
        MONDIAL_RELAY_SENDER_POSTAL_CODE
        MONDIAL_RELAY_SENDER_CITY
        MONDIAL_RELAY_SENDER_COUNTRY
        MONDIAL_RELAY_SENDER_PHONE
        MONDIAL_RELAY_COLLECTION_MODE
        MONDIAL_RELAY_PICKUP_DELIVERY_MODE
        MONDIAL_RELAY_HOME_DELIVERY_MODE
      ].freeze

      def self.configured?
        REQUIRED_ENV.all? { |key| ENV[key].present? }
      end

      def create(order:)
        ensure_configured!
        raise Unavailable, "Le poids d’expédition de la commande est requis pour créer l’étiquette." unless order.shipping_weight_grams.to_i.positive?

        values = request_values(order)
        response = post_soap(values)
        result_from(response.body, order)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError => error
        Rails.logger.warn("Mondial Relay expédition indisponible: #{error.class}")
        raise Unavailable, "Le service Mondial Relay est momentanément indisponible."
      end

      private

      def ensure_configured!
        return if self.class.configured?

        raise Unavailable, "La création d’expédition Mondial Relay n’est pas encore configurée."
      end

      def request_values(order)
        values = {
          "Enseigne" => ENV.fetch("MONDIAL_RELAY_BRAND_CODE"),
          "ModeCol" => ENV.fetch("MONDIAL_RELAY_COLLECTION_MODE"),
          "ModeLiv" => delivery_mode(order),
          "NDossier" => order.public_token.first(15).upcase,
          "NClient" => "",
          "Expe_Langage" => "FR",
          "Expe_Ad1" => ENV.fetch("MONDIAL_RELAY_SENDER_NAME"),
          "Expe_Ad2" => ENV.fetch("MONDIAL_RELAY_SENDER_ADDRESS_LINE2", ""),
          "Expe_Ad3" => ENV.fetch("MONDIAL_RELAY_SENDER_ADDRESS_LINE1"),
          "Expe_Ad4" => "",
          "Expe_Ville" => ENV.fetch("MONDIAL_RELAY_SENDER_CITY"),
          "Expe_CP" => ENV.fetch("MONDIAL_RELAY_SENDER_POSTAL_CODE"),
          "Expe_Pays" => ENV.fetch("MONDIAL_RELAY_SENDER_COUNTRY"),
          "Expe_Tel1" => ENV.fetch("MONDIAL_RELAY_SENDER_PHONE"),
          "Expe_Tel2" => "",
          "Expe_Mail" => ENV.fetch("MONDIAL_RELAY_SENDER_EMAIL", ""),
          "Dest_Langage" => "FR",
          "Dest_Ad1" => order.customer_name,
          "Dest_Ad2" => "",
          "Dest_Ad3" => order.address_line1,
          "Dest_Ad4" => order.address_line2.to_s,
          "Dest_Ville" => order.city,
          "Dest_CP" => order.postal_code,
          "Dest_Pays" => order.country_code,
          "Dest_Tel1" => order.phone,
          "Dest_Tel2" => "",
          "Dest_Mail" => order.email,
          "Poids" => order.shipping_weight_grams.to_i.to_s,
          "Longueur" => "",
          "Taille" => "",
          "NbColis" => "1",
          "CRT_Valeur" => "0",
          "CRT_Devise" => "EUR",
          "Exp_Valeur" => order.total_cents.to_s,
          "Exp_Devise" => "EUR",
          "COL_Rel_Pays" => "",
          "COL_Rel" => "",
          "LIV_Rel_Pays" => order.relay_point&.relay_country.to_s,
          "LIV_Rel" => order.relay_point&.relay_id.to_s,
          "TAvisage" => "",
          "TReprise" => "",
          "Montage" => "",
          "TRDV" => "",
          "Assurance" => "",
          "Instructions" => "",
          "Texte" => ""
        }
        values["Security"] = Digest::MD5.hexdigest((values.values.join + ENV.fetch("MONDIAL_RELAY_PRIVATE_KEY")).upcase)
        values
      end

      def delivery_mode(order)
        order.relay_point ? ENV.fetch("MONDIAL_RELAY_PICKUP_DELIVERY_MODE") : ENV.fetch("MONDIAL_RELAY_HOME_DELIVERY_MODE")
      end

      def post_soap(values)
        request = Net::HTTP::Post.new(ENDPOINT.request_uri)
        request["Content-Type"] = "text/xml; charset=utf-8"
        request["SOAPAction"] = SOAP_ACTION
        request.body = soap_envelope(values)

        response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 4, read_timeout: 10) { |http| http.request(request) }
        raise Unavailable, "Le service Mondial Relay est momentanément indisponible." unless response.is_a?(Net::HTTPSuccess)

        response
      end

      def soap_envelope(values)
        fields = values.map { |name, value| "<#{name}>#{ERB::Util.html_escape(value)}</#{name}>" }.join
        %(<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><WSI2_CreationEtiquette xmlns="http://www.mondialrelay.fr/webservice/">#{fields}</WSI2_CreationEtiquette></soap:Body></soap:Envelope>)
      end

      def result_from(xml, order)
        document = REXML::Document.new(xml)
        result = REXML::XPath.first(document, "//*[local-name()='WSI2_CreationEtiquetteResult']")
        raise Unavailable, "Mondial Relay n’a pas retourné d’expédition exploitable." unless result

        status = result.elements["STAT"]&.text.to_s.strip
        raise Unavailable, "Mondial Relay a refusé la création de l’expédition#{" (code #{status})" if status.present? && status != "0"}." if status.present? && status != "0"

        shipment_id = result.elements["ExpeditionNum"]&.text.to_s.strip
        label_url = result.elements["URL_Etiquette"]&.text.to_s.strip
        raise Unavailable, "Mondial Relay n’a pas retourné de numéro d’expédition." if shipment_id.blank?

        ShipmentResult.new(
          CARRIER,
          delivery_mode(order),
          shipment_id,
          shipment_id,
          Order::PUBLIC_TRACKING_PAGES.fetch(CARRIER),
          safe_label_url(label_url),
          nil,
          nil,
          { "provider" => "mondial_relay", "status" => status.presence || "0", "label_available" => label_url.present? }
        )
      rescue REXML::ParseException
        raise Unavailable, "Le service Mondial Relay a retourné une réponse invalide."
      end

      def safe_label_url(value)
        return if value.blank?

        uri = URI.parse(value)
        return uri.to_s if uri.is_a?(URI::HTTPS) && LABEL_HOSTS.include?(uri.host)

        raise Unavailable, "Mondial Relay a retourné un lien d’étiquette invalide."
      rescue URI::InvalidURIError
        raise Unavailable, "Mondial Relay a retourné un lien d’étiquette invalide."
      end
    end
  end
end

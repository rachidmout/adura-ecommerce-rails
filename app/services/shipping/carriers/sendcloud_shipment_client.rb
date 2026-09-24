module Shipping
  module Carriers
    class SendcloudShipmentClient < BaseShipmentClient
      def self.configured?
        SendcloudClientBase.configured?
      end

      def initialize(carrier_code:, delivery_kind:, method_id_override: nil, client: nil, **options)
        @carrier_code = carrier_code.to_s.strip.downcase
        @delivery_kind = delivery_kind.to_s.strip
        @method_id_override = method_id_override.to_s.strip
        @client = client || SendcloudClientBase.new(**options)
      end

      def create(order:)
        raise Unavailable, "Le code transporteur Sendcloud est absent." if @carrier_code.blank?
        raise Unavailable, "Le poids d’expédition de la commande est requis pour créer l’étiquette." unless order.shipping_weight_grams.to_i.positive?

        method_id = resolve_shipping_method_id(order)
        response = @client.post_json(@client.panel_base_url, "/parcels", payload: { parcel: parcel_payload(order, method_id) })
        parcel = response.fetch("parcel", response.fetch("parcels", []).first)
        raise Unavailable, "Sendcloud n’a pas retourné d’expédition exploitable." unless parcel.is_a?(Hash) && parcel["id"].present?

        result_from(parcel, order, method_id)
      rescue SendcloudClientBase::Unavailable => error
        raise Unavailable, error.message
      rescue SendcloudClientBase::NotFound => error
        raise Unavailable, error.message
      end

      private

      def resolve_shipping_method_id(order)
        candidates = pickup_point?(order) ? pickup_point_candidates(order) : home_delivery_candidates(order)
        candidates = candidates.select { |method| method["id"].present? && compatible_weight?(method, order.shipping_weight_grams) }
        raise Unavailable, "Aucune méthode Sendcloud compatible n’est disponible pour cette livraison. Réessayez après avoir vérifié le transporteur et la destination." if candidates.empty?

        return candidates.find { |method| method.fetch("id").to_s == @method_id_override }&.fetch("id").to_i if @method_id_override.present? && candidates.any? { |method| method.fetch("id").to_s == @method_id_override }
        raise Unavailable, "L’ID Sendcloud de préférence n’est plus compatible. Supprimez-le ou choisissez une méthode disponible." if @method_id_override.present?

        candidates.min_by { |method| method.fetch("id").to_i }.fetch("id").to_i
      end

      def pickup_point_candidates(order)
        relay_id = order.relay_point&.relay_id.to_s
        raise Unavailable, "Le point relais de cette commande est introuvable." unless relay_id.match?(/\A\d+\z/)

        methods = @client.get_json(@client.panel_base_url, "/shipping_methods", params: { service_point_id: relay_id }).fetch("shipping_methods", [])
        methods.select { |method| carrier_matches?(method) }
      end

      def home_delivery_candidates(order)
        params = {
          from_country: sendcloud_origin_country,
          to_country: order.country_code,
          carrier: @carrier_code,
          weight: order.shipping_weight_grams,
          weight_unit: "gram",
          last_mile: "home_delivery",
          from_postal_code: ENV["SENDCLOUD_FROM_POSTAL_CODE"].presence,
          to_postal_code: order.postal_code.presence
        }
        response = @client.get_json(@client.panel_base_url, "/shipping-products", params:)
        shipping_product_groups(response).flat_map { |group| Array(group["methods"]) }.select { |method| carrier_matches?(method) }
      end

      def shipping_product_groups(response)
        return response if response.is_a?(Array)
        return response.fetch("shipping_products", []) if response.is_a?(Hash) && response.key?("shipping_products")

        Array(response.is_a?(Hash) ? response["results"] : response)
      end

      def carrier_matches?(method)
        method["carrier"].to_s == @carrier_code || method["shipping_product_code"].to_s.split(":").first == @carrier_code
      end

      def compatible_weight?(method, grams)
        properties = method["properties"] || {}
        min = properties["min_weight"] || method["min_weight"].to_f * 1000
        max = properties["max_weight"] || method["max_weight"].to_f * 1000
        grams.to_i >= min.to_f && (max.blank? || max.to_f.zero? || grams.to_i <= max.to_f)
      end

      def pickup_point?(order)
        @delivery_kind == "pickup_point" || order.relay_point.present?
      end

      def sendcloud_origin_country
        ENV.fetch("SENDCLOUD_FROM_COUNTRY", "FR").to_s.strip.upcase
      end

      def parcel_payload(order, method_id)
        {
          name: order.customer_name,
          address: order.address_line1,
          address_2: order.address_line2.to_s.presence,
          city: order.city,
          postal_code: order.postal_code,
          country: order.country_code,
          telephone: order.phone,
          email: order.email,
          weight: order.shipping_weight_grams.to_f / 1000,
          request_label: true,
          shipment: { id: method_id },
          to_service_point: pickup_point?(order) ? order.relay_point&.relay_id&.to_i : nil,
          order_number: order.public_token.first(15).upcase,
          external_order_id: order.id.to_s,
          shipping_method_checkout_name: order.shipping_method_name
        }.compact
      end

      def result_from(parcel, order, method_id)
        label_path = label_path_from(parcel)
        label_data = label_path && @client.get_pdf(@client.panel_base_url, label_path)
        tracking_number = parcel["tracking_number"].to_s.presence || parcel.dig("tracking", "tracking_number").to_s.presence || parcel.fetch("id").to_s

        ShipmentResult.new(
          order.shipping_carrier_name.presence || "Sendcloud",
          order.shipping_method_name.presence || "Livraison standard",
          parcel.fetch("id").to_s,
          tracking_number,
          safe_tracking_url(parcel["tracking_url"]),
          nil,
          label_data,
          "sendcloud-etiquette-#{order.public_token.first(8)}.pdf",
          {
            "provider" => "sendcloud",
            "parcel_id" => parcel.fetch("id").to_s,
            "shipping_method_id" => method_id,
            "carrier_code" => @carrier_code,
            "label_available" => label_data.present?,
            "destination_type" => order.relay_point.present? ? "pickup_point" : "home_delivery",
            "relay_id" => order.relay_point&.relay_id
          }.compact
        )
      end

      def label_path_from(parcel)
        value = parcel["label_url"].presence || parcel["label"].presence
        return if value.blank?

        value = value["url"] if value.is_a?(Hash)
        return if value.blank?

        value = value.to_s
        uri = URI.parse(value)
        return uri.request_uri if uri.is_a?(URI::HTTPS) && uri.host == @client.panel_base_url.host
        value if value.start_with?("/")
      rescue URI::InvalidURIError
        nil
      end

      def safe_tracking_url(value)
        uri = URI.parse(value.to_s)
        uri.to_s if uri.is_a?(URI::HTTPS)
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end

module Shipping
  module Carriers
    class SendcloudPickupPointClient < BasePickupPointClient
      SEARCH_RADIUS_METERS = 5_000

      def self.configured?
        SendcloudClientBase.configured?
      end

      def initialize(carrier_name:, carrier_code:, client: nil, **options)
        @carrier_name = carrier_name.to_s.strip
        @carrier_code = carrier_code.to_s.strip.downcase
        @client = client || SendcloudClientBase.new(**options)
      end

      def search(postal_code:, city:, country_code:, package_weight_grams:, limit:)
        validate_search!(postal_code:, country_code:, package_weight_grams:)
        points = @client.get_json(@client.service_points_base_url, "/service-points/", params: search_params(postal_code, country_code))
        raise Unavailable, "Sendcloud a retourné une réponse invalide." unless points.is_a?(Array)

        points.filter_map { |point| pickup_point_from(point) }.first(limit)
      rescue SendcloudClientBase::NotFound => error
        raise Unavailable, error.message
      rescue SendcloudClientBase::Unavailable => error
        raise Unavailable, error.message
      end

      def find(relay_id:, country_code:, package_weight_grams:)
        validate_find!(relay_id:, country_code:, package_weight_grams:)
        data = @client.get_json(@client.service_points_base_url, "/service-points/#{URI.encode_uri_component(relay_id)}")
        point = pickup_point_from(data)
        raise NotFound, "Le point relais sélectionné n’est plus disponible." unless point && point.country_code == country_code

        point
      rescue SendcloudClientBase::NotFound => error
        raise NotFound, error.message
      rescue SendcloudClientBase::Unavailable => error
        raise Unavailable, error.message
      end

      private

      def validate_search!(postal_code:, country_code:, package_weight_grams:)
        raise Unavailable, "Renseignez un code postal pour rechercher un point relais." if postal_code.to_s.strip.blank?
        raise Unavailable, "Le poids du colis est indisponible." unless package_weight_grams.to_i.positive?
        raise Unavailable, "Le pays de livraison est requis." unless country_code.to_s.match?(/\A[A-Z]{2}\z/)
        raise Unavailable, "Le code transporteur Sendcloud est requis pour cette méthode." if @carrier_code.blank?
      end

      def validate_find!(relay_id:, country_code:, package_weight_grams:)
        raise NotFound, "Le point relais sélectionné est invalide." unless relay_id.to_s.match?(/\A\d+\z/)
        validate_search!(postal_code: "lookup", country_code:, package_weight_grams:)
      end

      def search_params(postal_code, country_code)
        { country: country_code, address: postal_code, radius: SEARCH_RADIUS_METERS, carrier: @carrier_code }
      end

      def pickup_point_from(data)
        return unless data.is_a?(Hash) && data["id"].present? && data["name"].present?

        PickupPoint.new(
          @carrier_name,
          data.fetch("id").to_s,
          data.fetch("name"),
          [ data["street"], data["house_number"] ].compact_blank.join(" ").presence || "Point relais",
          nil,
          data["postal_code"].to_s,
          data["city"].to_s,
          data["country"].to_s.upcase,
          opening_hours(data["formatted_opening_times"]),
          data["distance"].to_f.then { |distance| distance.positive? ? (distance / 1000.0) : nil },
          { "source" => "sendcloud", "service_point_id" => data["id"].to_s, "carrier_code" => data["carrier"].to_s.presence }.compact
        )
      end

      def opening_hours(value)
        return if value.blank? || !value.respond_to?(:each)

        days = %w[Lun Mar Mer Jeu Ven Sam Dim]
        value.filter_map do |day, hours|
          next if Array(hours).empty?

          "#{days[day.to_i] || day}: #{Array(hours).join(' · ')}"
        end.join(" · ").presence
      end
    end
  end
end

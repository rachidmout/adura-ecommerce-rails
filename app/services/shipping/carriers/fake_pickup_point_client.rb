module Shipping
  module Carriers
    class FakePickupPointClient < BasePickupPointClient
      CARRIER = "Mondial Relay".freeze

      def search(postal_code:, city:, country_code:, package_weight_grams:, limit:)
        validate!(postal_code:, city:, country_code:, package_weight_grams:)

        points_for(postal_code:, city:, country_code:).first(limit)
      end

      def find(relay_id:, country_code:, package_weight_grams:)
        validate!(postal_code: "00000", city: "Test", country_code:, package_weight_grams:)
        points_for(postal_code: relay_id.to_s.split("-").second || "00000", city: "Point relais", country_code:).find { |point| point.relay_id == relay_id } || raise(NotFound, "Point relais introuvable.")
      end

      private

      def validate!(postal_code:, city:, country_code:, package_weight_grams:)
        raise Unavailable, "La recherche de point relais est disponible pour la France uniquement." unless country_code == "FR"
        raise Unavailable, "Renseignez un code postal français valide." unless postal_code.to_s.match?(/\A\d{5}\z/)
        raise Unavailable, "Renseignez votre ville pour rechercher un point relais." if city.to_s.strip.blank?
        raise Unavailable, "Le poids du colis est indisponible." unless package_weight_grams.to_i.positive?
      end

      def points_for(postal_code:, city:, country_code:)
        [
          point("MR-#{postal_code}-001", "ADURA Relais #{city.titleize}", "12 rue du Marché", postal_code, city, country_code, "Lun–Sam : 09:00–19:00", 0.4),
          point("MR-#{postal_code}-002", "Relais du Centre", "8 avenue de la Gare", postal_code, city, country_code, "Lun–Ven : 08:30–18:30 · Sam : 09:00–13:00", 0.9),
          point("MR-#{postal_code}-003", "Point relais des Halles", "24 place des Halles", postal_code, city, country_code, "Mar–Sam : 10:00–19:00", 1.6)
        ]
      end

      def point(relay_id, name, address_line1, postal_code, city, country_code, opening_hours, distance_km)
        PickupPoint.new(CARRIER, relay_id, name, address_line1, nil, postal_code, city.titleize, country_code, opening_hours, distance_km, { "source" => "fake" })
      end
    end
  end
end

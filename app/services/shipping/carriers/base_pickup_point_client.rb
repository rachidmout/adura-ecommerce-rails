module Shipping
  module Carriers
    class BasePickupPointClient
      class Unavailable < StandardError; end
      class NotFound < StandardError; end

      PickupPoint = Data.define(
        :carrier,
        :relay_id,
        :name,
        :address_line1,
        :address_line2,
        :postal_code,
        :city,
        :country_code,
        :opening_hours,
        :distance_km,
        :raw_data
      ) do
        def to_h
          super.merge(distance_km: distance_km).compact
        end
      end

      def search(postal_code:, city:, country_code:, package_weight_grams:, limit:)
        raise NotImplementedError
      end

      def find(relay_id:, country_code:, package_weight_grams:)
        raise NotImplementedError
      end
    end
  end
end

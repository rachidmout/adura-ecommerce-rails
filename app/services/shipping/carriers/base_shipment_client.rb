module Shipping
  module Carriers
    class BaseShipmentClient
      class Error < StandardError; end
      class Unavailable < Error; end

      ShipmentResult = Data.define(
        :carrier,
        :service,
        :carrier_shipment_id,
        :tracking_number,
        :tracking_url,
        :label_url,
        :label_data,
        :label_filename,
        :raw_response
      )

      def create(order:)
        raise NotImplementedError
      end
    end
  end
end

module Shipping
  module Carriers
    class FakeShipmentClient < BaseShipmentClient
      def create(order:)
        suffix = "#{order.id}-#{Time.current.to_i}"
        tracking_number = "FAKE#{order.id.to_s.rjust(8, '0')}"

        ShipmentResult.new(
          order.shipping_carrier_name.presence || "Transporteur de test",
          order.shipping_method_name.presence || "Livraison de test",
          "FAKE-SHIPMENT-#{suffix}",
          tracking_number,
          "https://example.test/tracking/#{tracking_number}",
          nil,
          fake_pdf(order, tracking_number),
          "adura-etiquette-#{order.public_token.first(8)}.pdf",
          {
            "source" => "fake",
            "destination_type" => order.relay_point.present? ? "pickup_point" : "home_delivery",
            "relay_id" => order.relay_point&.relay_id
          }.compact
        )
      end

      private

      def fake_pdf(order, tracking_number)
        <<~PDF
          %PDF-1.4
          % ADURA - étiquette de développement
          1 0 obj
          << /Type /Catalog /Pages 2 0 R >>
          endobj
          2 0 obj
          << /Type /Pages /Kids [3 0 R] /Count 1 >>
          endobj
          3 0 obj
          << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] >>
          endobj
          % Commande #{order.public_token.first(8)} — #{tracking_number}
          %%EOF
        PDF
      end
    end
  end
end

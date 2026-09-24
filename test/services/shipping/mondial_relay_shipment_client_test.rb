require "test_helper"

class Shipping::Carriers::MondialRelayShipmentClientTest < ActiveSupport::TestCase
  test "declares the credentials, sender identity and contractual modes required for API2" do
    required = Shipping::Carriers::MondialRelayShipmentClient::REQUIRED_ENV

    assert_includes required, "MONDIAL_RELAY_PRIVATE_KEY"
    assert_includes required, "MONDIAL_RELAY_SENDER_ADDRESS_LINE1"
    assert_includes required, "MONDIAL_RELAY_COLLECTION_MODE"
    assert_includes required, "MONDIAL_RELAY_PICKUP_DELIVERY_MODE"
    assert_includes required, "MONDIAL_RELAY_HOME_DELIVERY_MODE"
  end

  test "rejects an untrusted carrier label URL" do
    client = Shipping::Carriers::MondialRelayShipmentClient.new

    assert_raises(Shipping::Carriers::BaseShipmentClient::Unavailable) do
      client.send(:safe_label_url, "https://example.test/label.pdf")
    end
  end

  test "accepts the official Mondial Relay label host" do
    client = Shipping::Carriers::MondialRelayShipmentClient.new

    assert_equal "https://api.mondialrelay.fr/labels/test.pdf", client.send(:safe_label_url, "https://api.mondialrelay.fr/labels/test.pdf")
  end

  test "parses the API2 shipment and label response without persisting sensitive request data" do
    order = create_paid_order
    order.update!(shipping_weight_grams: 200)
    client = Shipping::Carriers::MondialRelayShipmentClient.new
    xml = <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <WSI2_CreationEtiquetteResponse>
            <WSI2_CreationEtiquetteResult>
              <STAT>0</STAT>
              <ExpeditionNum>12345678</ExpeditionNum>
              <URL_Etiquette>https://api.mondialrelay.fr/labels/12345678.pdf</URL_Etiquette>
            </WSI2_CreationEtiquetteResult>
          </WSI2_CreationEtiquetteResponse>
        </soap:Body>
      </soap:Envelope>
    XML

    previous_mode = ENV["MONDIAL_RELAY_HOME_DELIVERY_MODE"]
    ENV["MONDIAL_RELAY_HOME_DELIVERY_MODE"] = "24R"
    result = client.send(:result_from, xml, order)

    assert_equal "12345678", result.carrier_shipment_id
    assert_equal "12345678", result.tracking_number
    assert_equal "https://api.mondialrelay.fr/labels/12345678.pdf", result.label_url
    assert_equal({ "provider" => "mondial_relay", "status" => "0", "label_available" => true }, result.raw_response)
  ensure
    ENV["MONDIAL_RELAY_HOME_DELIVERY_MODE"] = previous_mode
  end
end

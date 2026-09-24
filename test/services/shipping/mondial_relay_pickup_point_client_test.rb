require "test_helper"

class Shipping::Carriers::MondialRelayPickupPointClientTest < ActiveSupport::TestCase
  test "parses the documented Point Relais response without exposing credentials" do
    xml = <<~XML
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <WSI4_PointRelais_RechercheResponse>
            <WSI4_PointRelais_RechercheResult>
              <PointsRelais>
                <PointRelais_Details>
                  <STAT>0</STAT><Num>12345</Num><LgAdr1>RELAIS TEST</LgAdr1><LgAdr2>1 RUE DE PARIS</LgAdr2>
                  <CP>75001</CP><Ville>PARIS</Ville><Pays>FR</Pays><Distance>1,2</Distance><Horaires_Lundi>09:00-18:00</Horaires_Lundi>
                </PointRelais_Details>
              </PointsRelais>
            </WSI4_PointRelais_RechercheResult>
          </WSI4_PointRelais_RechercheResponse>
        </soap:Body>
      </soap:Envelope>
    XML

    point = Shipping::Carriers::MondialRelayPickupPointClient.new.send(:parse_points, xml).first

    assert_equal "12345", point.relay_id
    assert_equal "RELAIS TEST", point.name
    assert_equal "1 RUE DE PARIS", point.address_line1
    assert_equal 1.2, point.distance_km
    assert_match "Lundi: 09:00-18:00", point.opening_hours
  end
end

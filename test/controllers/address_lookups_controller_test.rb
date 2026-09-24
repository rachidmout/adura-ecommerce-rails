require "test_helper"

class AddressLookupsControllerTest < ActionDispatch::IntegrationTest
  test "returns one French city from the internal endpoint" do
    with_cities([ "Paris" ]) do
      get address_cities_path(locale: nil), params: { country_code: "FR", postal_code: "75001" }, as: :json
    end

    assert_response :success
    assert_equal [ "Paris" ], response.parsed_body.fetch("cities")
  end

  test "returns multiple cities and leaves unsupported formats manual" do
    with_cities([ "Saint-Denis", "Saint-Denis-lès-Bourg" ]) do
      get address_cities_path(locale: nil), params: { country_code: "FR", postal_code: "93200" }, as: :json
    end
    assert_equal [ "Saint-Denis", "Saint-Denis-lès-Bourg" ], response.parsed_body.fetch("cities")

    get address_cities_path(locale: nil), params: { country_code: "BE", postal_code: "1000" }, as: :json
    assert_equal [], response.parsed_body.fetch("cities")
  end

  private

  def with_cities(cities)
    original = AddressLookup::France.method(:cities_for)
    AddressLookup::France.define_singleton_method(:cities_for) { |_postal_code| cities }
    yield
  ensure
    AddressLookup::France.define_singleton_method(:cities_for, original) if original
  end
end

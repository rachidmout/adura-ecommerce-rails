require "test_helper"

class AddressLookupFranceTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body)

  setup { Rails.cache.clear }

  test "returns sorted unique city names for a French postal code" do
    response = Response.new("200", [ { nom: "Paris" }, { nom: "Paris" }, { nom: "Paris 1er Arrondissement" } ].to_json)
    http = Struct.new(:response) { def get(*) = response }.new(response)

    with_http_start(->(*, &block) { block.call(http) }) do
      assert_equal [ "Paris", "Paris 1er Arrondissement" ], AddressLookup::France.cities_for("75001")
    end
  end

  test "does not call the API for an invalid French postal code" do
    with_http_start(->(*) { flunk "API should not be called" }) do
      assert_equal [], AddressLookup::France.cities_for("7500")
    end
  end

  test "falls back to an empty result when the API is unavailable" do
    with_http_start(->(*) { raise Timeout::Error }) do
      assert_equal [], AddressLookup::France.cities_for("75002")
    end
  end

  private

  def with_http_start(replacement)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, replacement)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original) if original
  end
end

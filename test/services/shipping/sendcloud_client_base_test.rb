require "test_helper"

class Shipping::Carriers::SendcloudClientBaseTest < ActiveSupport::TestCase
  class ResponseClient < Shipping::Carriers::SendcloudClientBase
    def initialize(*responses)
      super(public_key: "public-key", secret_key: "secret-key")
      @responses = responses
    end

    private

    def perform_request(_uri, _request)
      @responses.shift
    end
  end

  test "follows a same-host redirect for a Sendcloud GET request" do
    redirect = Net::HTTPMovedPermanently.new("1.1", "301", "Moved Permanently")
    redirect["location"] = "/api/v2/service-points/"
    success = Net::HTTPOK.new("1.1", "200", "OK")
    success.define_singleton_method(:body) { "[]" }

    result = ResponseClient.new(redirect, success).get_json(
      URI("https://servicepoints.sendcloud.sc/api/v2"), "/service-points", params: { country: "FR" }
    )

    assert_equal [], result
  end

  test "does not follow a Sendcloud redirect to another host" do
    redirect = Net::HTTPMovedPermanently.new("1.1", "301", "Moved Permanently")
    redirect["location"] = "https://example.test/service-points/"

    error = assert_raises(Shipping::Carriers::SendcloudClientBase::Unavailable) do
      ResponseClient.new(redirect).get_json(URI("https://servicepoints.sendcloud.sc/api/v2"), "/service-points")
    end

    assert_match(/redirection non sûre/, error.message)
  end

  test "distinguishes an invalid Sendcloud request from an unavailable service" do
    error = assert_raises(Shipping::Carriers::SendcloudClientBase::Unavailable) do
      ResponseClient.new(Net::HTTPBadRequest.new("1.1", "400", "Bad Request")).get_json(URI("https://servicepoints.sendcloud.sc/api/v2"), "/service-points")
    end

    assert_match(/points relais.*transporteur.*activés/i, error.message)
  end

  test "reports Sendcloud credential failures without exposing credentials" do
    error = assert_raises(Shipping::Carriers::SendcloudClientBase::Unavailable) do
      ResponseClient.new(Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")).get_json(URI("https://servicepoints.sendcloud.sc/api/v2"), "/service-points")
    end

    assert_match(/refuse l’accès/i, error.message)
    assert_no_match(/public-key|secret-key/, error.message)
  end
end

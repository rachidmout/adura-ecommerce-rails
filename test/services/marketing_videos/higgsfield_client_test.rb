require "test_helper"

class MarketingVideos::HiggsfieldClientTest < ActiveSupport::TestCase
  test "does not initialize while Higgsfield is disabled" do
    with_higgsfield_environment(enabled: false, credentials: "key:secret") do
      assert_not MarketingVideos::HiggsfieldClient.enabled?
      assert_raises(MarketingVideos::HiggsfieldClient::Disabled) { MarketingVideos::HiggsfieldClient.new }
    end
  end

  test "requires valid credentials and a documented image to video model" do
    with_higgsfield_environment(enabled: true, credentials: nil) do
      assert_not MarketingVideos::HiggsfieldClient.configured?
      assert_raises(MarketingVideos::HiggsfieldClient::CredentialsMissing) { MarketingVideos::HiggsfieldClient.new }
    end

    with_higgsfield_environment(enabled: true, credentials: "key:secret", model: "seedance_2_0_mini") do
      assert_not MarketingVideos::HiggsfieldClient.configured?
      assert_raises(MarketingVideos::HiggsfieldClient::ConfigurationError) { MarketingVideos::HiggsfieldClient.new }
    end
  end

  test "captures and sanitizes a JSON provider error without credentials" do
    with_higgsfield_environment(enabled: true, credentials: "key:secret") do
      client = MarketingVideos::HiggsfieldClient.new
      response = fake_response(
        code: "400",
        body: '{"error":"invalid prompt","token":"must-not-be-stored","echo":"key:secret"}'
      )

      error = client.send(:response_error_for, response)

      assert_equal "La demande envoyée à Higgsfield est invalide.", error.message
      assert_equal 400, error.diagnostics.fetch("http_status")
      assert_equal "invalid prompt", error.diagnostics.dig("parsed_error", "error")
      assert_equal "[REDACTED]", error.diagnostics.dig("parsed_error", "token")
      assert_not_includes error.diagnostics.fetch("error_body"), "key:secret"
      assert_not_includes error.diagnostics.fetch("error_body"), "must-not-be-stored"
      assert_equal "request-123", error.diagnostics.dig("response_headers", "x-request-id")
    end
  end

  test "captures a text provider error" do
    with_higgsfield_environment(enabled: true, credentials: "key:secret") do
      error = MarketingVideos::HiggsfieldClient.new.send(
        :response_error_for,
        fake_response(code: "422", body: "Prompt cannot be empty\nAuthorization: Bearer should-not-be-stored")
      )

      assert_includes error.diagnostics.fetch("error_body"), "Prompt cannot be empty"
      assert_not_includes error.diagnostics.fetch("error_body"), "should-not-be-stored"
      assert_nil error.diagnostics["parsed_error"]
    end
  end

  test "wraps documented image to video inputs in params without making a request" do
    with_higgsfield_environment(enabled: true, credentials: "key:secret") do
      client = MarketingVideos::HiggsfieldClient.new
      video_job = Struct.new(:higgsfield_prompt, :reference_image_url).new("Cinematic perfume video", "https://images.example.test/yara.jpg")
      captured_request = nil
      client.define_singleton_method(:request) do |method, path, body|
        captured_request = { method:, path:, body: }
        MarketingVideos::HiggsfieldClient::ResponsePayload.new(
          payload: { "status" => "queued", "request_id" => "hf-request-123" },
          diagnostics: {}
        )
      end

      client.submit(video_job)

      assert_equal :post, captured_request.fetch(:method)
      assert_equal "/v1/image2video/dop", captured_request.fetch(:path)
      assert_equal(
        {
          params: {
            model: "dop-turbo",
            prompt: "Cinematic perfume video",
            input_images: [ { type: "image_url", image_url: "https://images.example.test/yara.jpg" } ]
          }
        },
        captured_request.fetch(:body)
      )
    end
  end

  test "captures a 200 JSON response without request id for diagnostics" do
    with_higgsfield_environment(enabled: true, credentials: "key:secret") do
      client = MarketingVideos::HiggsfieldClient.new
      response_payload = client.send(
        :response_payload_for,
        fake_response(code: "200", body: '{"status":"queued","token":"must-not-be-stored","echo":"key:secret"}')
      )

      error = assert_raises(MarketingVideos::HiggsfieldClient::InvalidResponse) do
        client.send(:response_from, response_payload)
      end

      assert_equal "Higgsfield a retourné une réponse incomplète.", error.message
      assert_equal 200, error.diagnostics.fetch("http_status")
      assert_equal "queued", error.diagnostics.dig("parsed_response", "status")
      assert_equal "[REDACTED]", error.diagnostics.dig("parsed_response", "token")
      assert_not_includes error.diagnostics.fetch("response_body"), "must-not-be-stored"
      assert_not_includes error.diagnostics.fetch("response_body"), "key:secret"
    end
  end

  test "uses the root Higgsfield id and child job status from an accepted image to video request" do
    with_higgsfield_environment(enabled: true, credentials: "key:secret") do
      client = MarketingVideos::HiggsfieldClient.new
      response_payload = client.send(
        :response_payload_for,
        fake_response(
          code: "200",
          body: '{"id":"request-123","type":"image2video","jobs":[{"id":"child-job-456","status":"queued","results":null}],"input_params":{"token":"must-not-be-stored"}}'
        )
      )

      response = client.send(:response_from, response_payload)

      assert_equal "request-123", response.request_id
      assert_equal "queued", response.status
      assert_equal "request-123", response.raw_response.fetch("higgsfield_request_id")
      assert_equal "child-job-456", response.raw_response.fetch("higgsfield_child_job_id")
      assert_equal "queued", response.raw_response.fetch("initial_provider_status")
      assert_equal "[REDACTED]", response.raw_response.dig("input_params", "token")
    end
  end

  test "falls back to request id when a root id is absent" do
    with_higgsfield_environment(enabled: true, credentials: "key:secret") do
      client = MarketingVideos::HiggsfieldClient.new
      response_payload = client.send(:response_payload_for, fake_response(code: "200", body: '{"request_id":"legacy-request-123","status":"queued"}'))

      assert_equal "legacy-request-123", client.send(:response_from, response_payload).request_id
    end
  end

  private

  def with_higgsfield_environment(enabled:, credentials:, model: "dop-turbo")
    previous_values = %w[HIGGSFIELD_ENABLED HIGGSFIELD_CREDENTIALS HIGGSFIELD_MODEL].to_h { |key| [ key, ENV[key] ] }
    ENV["HIGGSFIELD_ENABLED"] = enabled.to_s
    ENV["HIGGSFIELD_CREDENTIALS"] = credentials
    ENV["HIGGSFIELD_MODEL"] = model
    yield
  ensure
    previous_values.each { |key, value| ENV[key] = value }
  end

  def fake_response(code:, body:)
    Struct.new(:code, :body) do
      def each_header
        { "content-type" => "application/json", "x-request-id" => "request-123", "authorization" => "never-store" }.each { |name, value| yield name, value }
      end
    end.new(code, body)
  end
end

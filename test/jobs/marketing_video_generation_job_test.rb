require "test_helper"

class MarketingVideoGenerationJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  test "stores a completed Higgsfield video without making a real request" do
    video_job = generating_video_job
    response = response_for(status: "completed", video_url: "https://media.example.test/yara.mp4")

    with_higgsfield_client(FakeHiggsfieldClient.new(submit_response: response)) do |worker|
      assert_no_enqueued_jobs do
        worker.perform(video_job.id)
      end
    end

    video_job.reload
    assert_equal "generated", video_job.status
    assert_equal "hf-request-123", video_job.provider_job_id
    assert_equal "https://media.example.test/yara.mp4", video_job.result_video_url
    assert_not_nil video_job.generated_at
  end

  test "marks a failed Higgsfield request without making a real request" do
    video_job = generating_video_job
    client = FakeHiggsfieldClient.new(error: MarketingVideos::HiggsfieldClient::ResponseError.new("Higgsfield est momentanément indisponible."))

    with_higgsfield_client(client) do |worker|
      assert_no_enqueued_jobs do
        worker.perform(video_job.id)
      end
    end

    video_job.reload
    assert_equal "failed", video_job.status
    assert_equal "Higgsfield est momentanément indisponible.", video_job.error_message
    assert_not_nil video_job.failed_at
  end

  test "stores safe provider diagnostics when Higgsfield rejects a request" do
    video_job = generating_video_job
    client = FakeHiggsfieldClient.new(error: MarketingVideos::HiggsfieldClient::ResponseError.new(
      "La demande envoyée à Higgsfield est invalide.",
      diagnostics: {
        "provider" => "higgsfield", "http_status" => 400,
        "error_body" => '{"error":"invalid prompt","token":"[REDACTED]"}',
        "parsed_error" => { "error" => "invalid prompt", "token" => "[REDACTED]" }
      }
    ))

    with_higgsfield_client(client) { |worker| worker.perform(video_job.id) }

    video_job.reload
    assert_equal "failed", video_job.status
    assert_equal 400, video_job.raw_response.fetch("http_status")
    assert_equal "invalid prompt", video_job.raw_response.dig("parsed_error", "error")
    assert_equal "[REDACTED]", video_job.raw_response.dig("parsed_error", "token")
    assert_equal "dop-turbo", video_job.raw_response.dig("request_summary", "model")
    assert_equal true, video_job.raw_response.dig("request_summary", "has_prompt")
    assert_equal "images.example.test", video_job.raw_response.dig("request_summary", "reference_image_host")
    assert_not_includes video_job.raw_response.to_json, "key:secret"
  end

  test "stores a safe incomplete successful response for diagnosis" do
    video_job = generating_video_job
    client = FakeHiggsfieldClient.new(error: MarketingVideos::HiggsfieldClient::InvalidResponse.new(
      "Higgsfield a retourné une réponse incomplète.",
      diagnostics: {
        "provider" => "higgsfield", "http_status" => 200,
        "response_body" => '{"status":"queued","token":"[REDACTED]"}',
        "parsed_response" => { "status" => "queued", "token" => "[REDACTED]" },
        "response_headers" => { "content-type" => "application/json" }
      }
    ))

    with_higgsfield_client(client) { |worker| worker.perform(video_job.id) }

    video_job.reload
    assert_equal "failed", video_job.status
    assert_equal 200, video_job.raw_response.fetch("http_status")
    assert_equal "queued", video_job.raw_response.dig("parsed_response", "status")
    assert_equal "[REDACTED]", video_job.raw_response.dig("parsed_response", "token")
    assert_equal "application/json", video_job.raw_response.dig("response_headers", "content-type")
    assert_equal "dop-turbo", video_job.raw_response.dig("request_summary", "model")
    assert_not_includes video_job.raw_response.to_json, "key:secret"
  end

  test "stores the provider request id when Higgsfield reports a failed request" do
    video_job = generating_video_job
    response = response_for(status: "failed")

    with_higgsfield_client(FakeHiggsfieldClient.new(submit_response: response)) do |worker|
      worker.perform(video_job.id)
    end

    video_job.reload
    assert_equal "failed", video_job.status
    assert_equal "hf-request-123", video_job.provider_job_id
  end

  test "saves a provider request id then schedules polling for an unfinished generation" do
    video_job = generating_video_job
    response = response_for(status: "queued")

    with_higgsfield_client(FakeHiggsfieldClient.new(submit_response: response)) do |worker|
      assert_enqueued_with(job: MarketingVideoGenerationJob, args: [ video_job.id ]) do
        worker.perform(video_job.id)
      end
    end

    video_job.reload
    assert_equal "generating", video_job.status
    assert_equal "hf-request-123", video_job.provider_job_id
    assert_equal "queued", video_job.raw_response.fetch("status")
  end

  test "uses the root Higgsfield request id for polling and preserves child job details" do
    video_job = generating_video_job
    response = MarketingVideos::HiggsfieldClient::Response.new(
      status: "queued",
      request_id: "hf-root-request-123",
      status_url: nil,
      cancel_url: nil,
      video_url: nil,
      raw_response: {
        "id" => "hf-root-request-123",
        "jobs" => [ { "id" => "hf-child-job-456", "status" => "queued" } ],
        "higgsfield_request_id" => "hf-root-request-123",
        "higgsfield_child_job_id" => "hf-child-job-456",
        "initial_provider_status" => "queued"
      }
    )

    with_higgsfield_client(FakeHiggsfieldClient.new(submit_response: response)) do |worker|
      worker.perform(video_job.id)
    end

    video_job.reload
    assert_equal "generating", video_job.status
    assert_equal "hf-root-request-123", video_job.provider_job_id
    assert_equal "hf-child-job-456", video_job.raw_response.fetch("higgsfield_child_job_id")
    assert_equal "queued", video_job.raw_response.fetch("initial_provider_status")
  end

  test "polls an existing provider request and stores the completed video" do
    video_job = generating_video_job
    video_job.update!(provider_job_id: "hf-existing-request")
    client = FakeHiggsfieldClient.new(status_response: response_for(status: "completed", video_url: "https://media.example.test/yara-polled.mp4"))

    with_higgsfield_client(client) do |worker|
      worker.perform(video_job.id)
    end

    video_job.reload
    assert_equal "hf-existing-request", client.status_request_id
    assert_equal "generated", video_job.status
    assert_equal "https://media.example.test/yara-polled.mp4", video_job.result_video_url
  end

  private

  def generating_video_job
    MarketingVideoJob.create!(
      product_slug: "yara", product_name: "Yara", higgsfield_prompt: "Cinematic perfume video", duration_seconds: 10,
      aspect_ratio: "9:16", reference_image_url: "https://images.example.test/yara.jpg",
      watermark_text: "ADURA.STORE", watermark_position: "center_lower", screen_texts: [], hashtags: [], status: "approved", reviewed_at: Time.current
    ).tap(&:start_generation!)
  end

  def response_for(status:, video_url: nil)
    MarketingVideos::HiggsfieldClient::Response.new(
      status: status,
      request_id: "hf-request-123",
      status_url: "https://platform.higgsfield.ai/requests/hf-request-123/status",
      cancel_url: "https://platform.higgsfield.ai/requests/hf-request-123/cancel",
      video_url: video_url,
      raw_response: { "status" => status, "request_id" => "hf-request-123" }
    )
  end

  def with_higgsfield_client(client)
    previous_factory = MarketingVideoGenerationJob.higgsfield_client_factory
    MarketingVideoGenerationJob.higgsfield_client_factory = -> { client }
    yield MarketingVideoGenerationJob.new
  ensure
    MarketingVideoGenerationJob.higgsfield_client_factory = previous_factory
  end

  class FakeHiggsfieldClient
    attr_reader :status_request_id

    def initialize(submit_response: nil, status_response: nil, error: nil)
      @submit_response = submit_response
      @status_response = status_response
      @error = error
    end

    def submit(_video_job)
      raise @error if @error

      @submit_response
    end

    def status(request_id)
      @status_request_id = request_id
      raise @error if @error

      @status_response
    end
  end
end

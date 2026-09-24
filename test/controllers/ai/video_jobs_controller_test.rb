require "test_helper"

class Ai::VideoJobsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @product = create_publishable_product(slug: "ai-video-job-yara")
  end

  test "refuses a request without the AI marketing token" do
    assert_no_difference "MarketingVideoJob.count" do
      post ai_video_jobs_path, params: valid_payload, as: :json
    end

    assert_response :unauthorized
  end

  test "refuses an incorrect AI marketing token" do
    with_ai_marketing_token do
      assert_no_difference "MarketingVideoJob.count" do
        post ai_video_jobs_path, params: valid_payload, as: :json, headers: authorization_header("incorrect")
      end
    end

    assert_response :unauthorized
  end

  test "creates a pending review video job without any external generation" do
    with_ai_marketing_token do |token|
      assert_difference "MarketingVideoJob.count", 1 do
        assert_no_enqueued_jobs do
          post ai_video_jobs_path, params: valid_payload, as: :json, headers: authorization_header(token)
        end
      end
    end

    assert_response :created
    video_job = MarketingVideoJob.order(:created_at).last
    assert_equal "pending_review", video_job.status
    assert_equal "higgsfield", video_job.provider
    assert_equal @product.name, video_job.product_name
    assert_equal valid_payload[:product_slug], video_job.raw_request.fetch("product_slug")
    assert_equal [ "YARA", "Doux, crémeux, féminin", "ADURA.STORE" ], video_job.screen_texts
    assert_equal({ "id" => video_job.id, "status" => "pending_review" }, response.parsed_body)
  end

  test "refuses an unknown or unpublished product slug" do
    with_ai_marketing_token do |token|
      assert_no_difference "MarketingVideoJob.count" do
        post ai_video_jobs_path, params: valid_payload.merge(product_slug: "unknown-product"), as: :json, headers: authorization_header(token)
      end
    end

    assert_response :unprocessable_entity
    assert_equal "Produit introuvable ou non publié.", response.parsed_body.fetch("error")
  end

  test "refuses an invalid duration" do
    with_ai_marketing_token do |token|
      assert_no_difference "MarketingVideoJob.count" do
        post ai_video_jobs_path, params: valid_payload.merge(duration_seconds: 16), as: :json, headers: authorization_header(token)
      end
    end

    assert_response :unprocessable_entity
    assert response.parsed_body.fetch("errors").key?("duration_seconds")
  end

  test "refuses an invalid watermark" do
    with_ai_marketing_token do |token|
      assert_no_difference "MarketingVideoJob.count" do
        post ai_video_jobs_path, params: valid_payload.merge(watermark_text: "OTHER.STORE"), as: :json, headers: authorization_header(token)
      end
    end

    assert_response :unprocessable_entity
    assert response.parsed_body.fetch("errors").key?("watermark_text")
  end

  private

  def valid_payload
    {
      product_slug: @product.slug,
      objective: "conversion TikTok",
      marketing_angle: "parfum doux et gourmand du quotidien",
      hook: "Tu veux un parfum doux, féminin et facile à porter ?",
      script: "Plan flacon puis plan texture.",
      screen_texts: [ "YARA", "Doux, crémeux, féminin", "ADURA.STORE" ],
      caption: "Un parfum doux à découvrir chez ADURA.",
      hashtags: [ "parfum", "yara", "lattafa", "parfumfemme" ],
      higgsfield_prompt: "Vertical premium perfume video, soft cream background.",
      duration_seconds: 10,
      aspect_ratio: "9:16",
      reference_image_url: "https://images.example.test/yara.jpg",
      watermark_text: "ADURA.STORE",
      watermark_position: "center_lower"
    }
  end

  def with_ai_marketing_token
    previous_token = ENV["AI_MARKETING_API_TOKEN"]
    ENV["AI_MARKETING_API_TOKEN"] = "test-ai-marketing-token"
    yield ENV.fetch("AI_MARKETING_API_TOKEN")
  ensure
    ENV["AI_MARKETING_API_TOKEN"] = previous_token
  end

  def authorization_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end

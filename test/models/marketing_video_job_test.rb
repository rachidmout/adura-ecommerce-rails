require "test_helper"

class MarketingVideoJobTest < ActiveSupport::TestCase
  test "accepts a valid review-only Higgsfield request" do
    video_job = build_video_job

    assert_predicate video_job, :valid?
    assert_equal "pending_review", video_job.status
    assert_equal "higgsfield", video_job.provider
  end

  test "requires the fixed vertical format and ADURA watermark" do
    video_job = build_video_job(aspect_ratio: "1:1", watermark_text: "OTHER.STORE", watermark_position: "top")

    assert_not_predicate video_job, :valid?
    assert video_job.errors.of_kind?(:aspect_ratio, :inclusion)
    assert video_job.errors.of_kind?(:watermark_text, :inclusion)
    assert video_job.errors.of_kind?(:watermark_position, :inclusion)
  end

  test "requires an HTTPS reference image and a Higgsfield prompt" do
    video_job = build_video_job(reference_image_url: "http://example.test/yara.jpg", higgsfield_prompt: nil)

    assert_not_predicate video_job, :valid?
    assert_includes video_job.errors[:reference_image_url], "doit être une URL HTTPS valide"
    assert video_job.errors.of_kind?(:higgsfield_prompt, :blank)
  end

  test "approves or rejects a pending review job once" do
    approved_job = build_video_job.tap(&:save!)
    rejected_job = build_video_job(product_slug: "yara-copy", product_name: "Yara Copie").tap(&:save!)

    approved_job.approve!
    rejected_job.reject!

    assert_equal "approved", approved_job.status
    assert_not_nil approved_job.reviewed_at
    assert_equal "rejected", rejected_job.status
    assert_not_nil rejected_job.reviewed_at
    assert_raises(ActiveRecord::RecordInvalid) { approved_job.reject! }
    assert_equal "approved", approved_job.reload.status
  end

  test "allows admin deletion only before generation starts" do
    deletable_job = build_video_job.tap(&:save!)
    generating_job = build_video_job(product_slug: "yara-generating", product_name: "Yara Generating", status: "generating").tap(&:save!)
    generated_job = build_video_job(product_slug: "yara-generated", product_name: "Yara Generated", status: "generated").tap(&:save!)

    assert_predicate deletable_job, :deletable_by_admin?
    assert_not_predicate generating_job, :deletable_by_admin?
    assert_not_predicate generated_job, :deletable_by_admin?

    deletable_job.destroy_by_admin!

    assert_not MarketingVideoJob.exists?(deletable_job.id)
    assert_raises(ActiveRecord::RecordInvalid) { generating_job.destroy_by_admin! }
    assert_raises(ActiveRecord::RecordInvalid) { generated_job.destroy_by_admin! }
    assert MarketingVideoJob.exists?(generating_job.id)
    assert MarketingVideoJob.exists?(generated_job.id)
  end

  test "queues an approved and complete job for generation once without marking it generated" do
    video_job = build_video_job(status: "approved", reviewed_at: Time.current).tap(&:save!)

    assert_predicate video_job, :queueable_by_admin?

    video_job.mark_queued_for_generation!

    assert_equal "queued_for_generation", video_job.status
    assert_not_nil video_job.queued_for_generation_at
    assert_nil video_job.generated_at
    assert_raises(ActiveRecord::RecordInvalid) { video_job.mark_queued_for_generation! }
    assert_equal "queued_for_generation", video_job.reload.status
  end

  test "does not queue jobs that are not approved and complete" do
    %w[pending_review rejected queued_for_generation generating generated].each do |status|
      video_job = build_video_job(product_slug: "yara-#{status}", product_name: "Yara #{status}", status: status).tap(&:save!)

      assert_not_predicate video_job, :queueable_by_admin?
      assert_raises(ActiveRecord::RecordInvalid) { video_job.mark_queued_for_generation! }
      assert_equal status, video_job.reload.status
    end
  end

  test "starts a real generation only once from approved, queued, or failed" do
    %w[approved queued_for_generation failed].each do |status|
      video_job = build_video_job(product_slug: "yara-#{status}", product_name: "Yara #{status}", status: status).tap(&:save!)

      assert_predicate video_job, :generatable_by_admin?
      video_job.start_generation!

      assert_equal "generating", video_job.status
      assert_not_nil video_job.generation_started_at
      assert_nil video_job.provider_job_id
      assert_nil video_job.generated_at
      assert_raises(ActiveRecord::RecordInvalid) { video_job.start_generation! }
    end
  end

  test "does not start a real generation from non-generatable statuses" do
    %w[pending_review rejected generating generated].each do |status|
      video_job = build_video_job(product_slug: "yara-not-#{status}", product_name: "Yara not #{status}", status: status).tap(&:save!)

      assert_not_predicate video_job, :generatable_by_admin?
      assert_raises(ActiveRecord::RecordInvalid) { video_job.start_generation! }
      assert_equal status, video_job.reload.status
    end
  end

  private

  def build_video_job(**attributes)
    MarketingVideoJob.new({
      product_slug: "yara", product_name: "Yara", higgsfield_prompt: "Prompt", duration_seconds: 10,
      aspect_ratio: "9:16", reference_image_url: "https://images.example.test/yara.jpg",
      watermark_text: "ADURA.STORE", watermark_position: "center_lower", screen_texts: [], hashtags: []
    }.merge(attributes))
  end
end

require "test_helper"

module Admin
  class MarketingVideoJobsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    test "requires an authenticated admin" do
      get admin_marketing_video_jobs_path

      assert_redirected_to admin_login_path
    end

    test "lists and shows a pending video job with review actions only" do
      job = create_video_job
      sign_in_as(create_admin_user)

      get admin_marketing_video_jobs_path

      assert_response :success
      assert_select "h1", "Vidéos marketing"
      assert_select ".admin-table", text: /#{Regexp.escape(job.product_name)}.*#{Regexp.escape(job.marketing_angle)}/
      assert_select "a[href=?]", admin_marketing_video_job_path(job), text: "Voir"
      assert_select "form[action=?] button[data-turbo-confirm=?]", admin_marketing_video_job_path(job), "Supprimer définitivement cette demande vidéo ?", text: "Supprimer"

      get admin_marketing_video_job_path(job)

      assert_response :success
      assert_select "h1", job.product_name
      assert_select "img.admin-video-reference-image[src=?]", job.reference_image_url
      assert_select "form[action=?] button", approve_admin_marketing_video_job_path(job), text: "Valider"
      assert_select "form[action=?] button", reject_admin_marketing_video_job_path(job), text: "Rejeter"
      assert_select "button[disabled]", text: /Générer avec Higgsfield/
      assert_select "form[action=?] button[data-turbo-confirm=?]", admin_marketing_video_job_path(job), "Supprimer définitivement cette demande vidéo ?", text: "Supprimer la demande"
    end

    test "an admin approves a pending review job without external generation" do
      job = create_video_job
      sign_in_as(create_admin_user)

      assert_no_enqueued_jobs do
        patch approve_admin_marketing_video_job_path(job)
      end

      assert_redirected_to admin_marketing_video_job_path(job)
      assert_equal "approved", job.reload.status
      assert_not_nil job.reviewed_at
      follow_redirect!
      assert_select ".flash", text: "La demande vidéo a été validée."
      assert_select "button[disabled]", text: "Valider"
      assert_select "button[disabled]", text: "Rejeter"
      assert_select "form[action=?] button", generate_admin_marketing_video_job_path(job), text: "Générer avec Higgsfield"
    end

    test "an admin rejects a pending review job without external generation" do
      job = create_video_job
      sign_in_as(create_admin_user)

      assert_no_enqueued_jobs do
        patch reject_admin_marketing_video_job_path(job)
      end

      assert_redirected_to admin_marketing_video_job_path(job)
      assert_equal "rejected", job.reload.status
      assert_not_nil job.reviewed_at
    end

    test "an admin cannot review an already treated job again" do
      job = create_video_job(status: "approved", reviewed_at: 1.minute.ago)
      sign_in_as(create_admin_user)

      assert_no_enqueued_jobs do
        patch reject_admin_marketing_video_job_path(job)
      end

      assert_redirected_to admin_marketing_video_job_path(job)
      assert_equal "approved", job.reload.status
      follow_redirect!
      assert_select ".flash", text: "Cette demande vidéo a déjà été traitée."
    end

    test "disabled Higgsfield leaves an approved job unchanged" do
      job = create_video_job(status: "approved", reviewed_at: 1.minute.ago)
      sign_in_as(create_admin_user)

      assert_no_enqueued_jobs do
        patch generate_admin_marketing_video_job_path(job)
      end

      assert_redirected_to admin_marketing_video_job_path(job)
      assert_equal "approved", job.reload.status
      follow_redirect!
      assert_select ".flash", text: "La génération Higgsfield est désactivée."
    end

    test "missing Higgsfield credentials leave an approved job unchanged" do
      job = create_video_job(status: "approved", reviewed_at: 1.minute.ago)
      sign_in_as(create_admin_user)

      with_higgsfield_environment(enabled: true, credentials: nil) do
        assert_no_enqueued_jobs { patch generate_admin_marketing_video_job_path(job) }
      end

      assert_equal "approved", job.reload.status
      follow_redirect!
      assert_select ".flash", text: "Les identifiants ou le modèle Higgsfield ne sont pas configurés correctement."
    end

    test "an admin enqueues generation for approved, queued, and failed jobs without calling Higgsfield in the request" do
      sign_in_as(create_admin_user)

      %w[approved queued_for_generation failed].each do |status|
        job = create_video_job(status: status, reviewed_at: (Time.current if status == "approved"))

        with_higgsfield_environment(enabled: true, credentials: "key:secret") do
          assert_enqueued_with(job: MarketingVideoGenerationJob, args: [ job.id ]) do
            patch generate_admin_marketing_video_job_path(job)
          end
        end

        assert_redirected_to admin_marketing_video_job_path(job)
        assert_equal "generating", job.reload.status
        assert_not_nil job.generation_started_at
      end
    end

    test "an admin cannot start generation from pending review, rejected, generating, or generated" do
      sign_in_as(create_admin_user)

      %w[pending_review rejected generating generated].each do |status|
        job = create_video_job(status: status)

        with_higgsfield_environment(enabled: true, credentials: "key:secret") do
          assert_no_enqueued_jobs do
          patch generate_admin_marketing_video_job_path(job)
          end
        end

        assert_redirected_to admin_marketing_video_job_path(job)
        assert_equal status, job.reload.status
      end
    end

    test "an admin deletes pending review, approved, and rejected jobs without external generation" do
      sign_in_as(create_admin_user)

      %w[pending_review approved rejected].each do |status|
        job = create_video_job(status: status, reviewed_at: (Time.current if status != "pending_review"))

        assert_no_enqueued_jobs do
          delete admin_marketing_video_job_path(job)
        end

        assert_redirected_to admin_marketing_video_jobs_path
        assert_not MarketingVideoJob.exists?(job.id)
      end
    end

    test "an admin cannot delete generating or generated jobs" do
      sign_in_as(create_admin_user)

      %w[generating generated].each do |status|
        job = create_video_job(status: status)

        assert_no_enqueued_jobs do
          delete admin_marketing_video_job_path(job)
        end

        assert_redirected_to admin_marketing_video_job_path(job)
        assert MarketingVideoJob.exists?(job.id)
      end

      get admin_marketing_video_job_path(MarketingVideoJob.find_by!(status: "generating"))

      assert_select "button[disabled]", text: "Non supprimable"
    end

    private

    def create_video_job(**attributes)
      MarketingVideoJob.create!({
        product_slug: "yara", product_name: "Yara", objective: "conversion TikTok",
        marketing_angle: "gourmand", hook: "Un hook", script: "Un script", screen_texts: [ "YARA" ],
        caption: "Une caption", hashtags: [ "yara" ], higgsfield_prompt: "Un prompt", duration_seconds: 10,
        aspect_ratio: "9:16", reference_image_url: "https://images.example.test/yara.jpg",
        watermark_text: "ADURA.STORE", watermark_position: "center_lower"
      }.merge(attributes))
    end

    def with_higgsfield_environment(enabled:, credentials:, model: "dop-turbo")
      previous_values = %w[HIGGSFIELD_ENABLED HIGGSFIELD_CREDENTIALS HIGGSFIELD_MODEL].to_h { |key| [ key, ENV[key] ] }
      ENV["HIGGSFIELD_ENABLED"] = enabled.to_s
      ENV["HIGGSFIELD_CREDENTIALS"] = credentials
      ENV["HIGGSFIELD_MODEL"] = model
      yield
    ensure
      previous_values.each { |key, value| ENV[key] = value }
    end
  end
end

class CreateMarketingVideoJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :marketing_video_jobs do |t|
      t.string :product_slug, null: false
      t.string :product_name, null: false
      t.string :objective
      t.string :marketing_angle
      t.text :hook
      t.text :script
      t.jsonb :screen_texts, null: false, default: []
      t.text :caption
      t.jsonb :hashtags, null: false, default: []
      t.text :higgsfield_prompt, null: false
      t.integer :duration_seconds, null: false
      t.string :aspect_ratio, null: false
      t.text :reference_image_url, null: false
      t.string :watermark_text, null: false
      t.string :watermark_position, null: false
      t.string :status, null: false, default: "pending_review"
      t.string :provider, null: false, default: "higgsfield"
      t.string :provider_job_id
      t.jsonb :raw_request, null: false, default: {}
      t.jsonb :raw_response, null: false, default: {}
      t.text :result_video_url
      t.text :watermarked_video_url
      t.text :error_message
      t.datetime :reviewed_at
      t.datetime :generated_at

      t.timestamps
    end

    add_index :marketing_video_jobs, :status
    add_index :marketing_video_jobs, :product_slug
    add_check_constraint :marketing_video_jobs, "status IN ('pending_review', 'approved', 'rejected', 'generating', 'generated', 'failed')", name: "marketing_video_jobs_valid_status"
    add_check_constraint :marketing_video_jobs, "duration_seconds BETWEEN 5 AND 15", name: "marketing_video_jobs_valid_duration"
    add_check_constraint :marketing_video_jobs, "aspect_ratio = '9:16'", name: "marketing_video_jobs_vertical_only"
    add_check_constraint :marketing_video_jobs, "watermark_text = 'ADURA.STORE'", name: "marketing_video_jobs_valid_watermark"
    add_check_constraint :marketing_video_jobs, "watermark_position = 'center_lower'", name: "marketing_video_jobs_valid_watermark_position"
  end
end

class AddQueuedForGenerationToMarketingVideoJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :marketing_video_jobs, :queued_for_generation_at, :datetime

    remove_check_constraint :marketing_video_jobs, name: "marketing_video_jobs_valid_status"
    add_check_constraint :marketing_video_jobs,
                         "status IN ('pending_review', 'approved', 'rejected', 'queued_for_generation', 'generating', 'generated', 'failed')",
                         name: "marketing_video_jobs_valid_status"
  end
end

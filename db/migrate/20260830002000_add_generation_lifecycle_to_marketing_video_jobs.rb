class AddGenerationLifecycleToMarketingVideoJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :marketing_video_jobs, :generation_started_at, :datetime
    add_column :marketing_video_jobs, :failed_at, :datetime
  end
end

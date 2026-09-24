class MarketingVideoGenerationJob < ActiveJob::Base
  POLL_INTERVAL = 20.seconds
  MAX_POLL_AGE = 15.minutes

  self.enqueue_after_transaction_commit = true
  queue_as :default
  class_attribute :higgsfield_client_factory, default: -> { MarketingVideos::HiggsfieldClient.new }

  def perform(marketing_video_job_id)
    video_job = MarketingVideoJob.find(marketing_video_job_id)
    return unless video_job.generating?

    client = higgsfield_client
    response = video_job.provider_job_id.present? ? client.status(video_job.provider_job_id) : client.submit(video_job)

    process_response(video_job, response)
  rescue ActiveRecord::RecordNotFound
    nil
  rescue MarketingVideos::HiggsfieldClient::Error => error
    video_job&.mark_generation_failed!(error.message, raw_response: failure_diagnostics_for(video_job, error))
  rescue StandardError
    video_job&.mark_generation_failed!("Une erreur interne a empêché la génération Higgsfield.")
  end

  private

  def higgsfield_client
    self.class.higgsfield_client_factory.call
  end

  def process_response(video_job, response)
    video_job.apply_higgsfield_response!(response)
    return unless video_job.reload.generating?

    if video_job.generation_started_at && video_job.generation_started_at < MAX_POLL_AGE.ago
      video_job.mark_generation_failed!("La génération Higgsfield a dépassé le délai de suivi autorisé.")
    else
      self.class.set(wait: POLL_INTERVAL).perform_later(video_job.id)
    end
  end

  def failure_diagnostics_for(video_job, error)
    provider_diagnostics = error.respond_to?(:diagnostics) ? error.diagnostics : {}

    provider_diagnostics.merge(
      "provider" => "higgsfield",
      "request_summary" => {
        "model" => ENV.fetch("HIGGSFIELD_MODEL", MarketingVideos::HiggsfieldClient::DEFAULT_MODEL),
        "has_prompt" => video_job.higgsfield_prompt.present?,
        "prompt_length" => video_job.higgsfield_prompt.to_s.length,
        "has_reference_image_url" => video_job.reference_image_url.present?,
        "reference_image_host" => reference_image_host(video_job.reference_image_url),
        "duration_seconds" => video_job.duration_seconds,
        "aspect_ratio" => video_job.aspect_ratio
      }
    )
  end

  def reference_image_host(url)
    URI.parse(url.to_s).host
  rescue URI::InvalidURIError
    nil
  end
end

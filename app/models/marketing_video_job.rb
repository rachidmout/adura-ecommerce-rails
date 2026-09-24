class MarketingVideoJob < ApplicationRecord
  STATUSES = %w[pending_review approved rejected queued_for_generation generating generated failed].freeze
  DELETABLE_STATUSES = %w[pending_review approved rejected].freeze
  PROVIDERS = %w[higgsfield].freeze
  WATERMARK_TEXT = "ADURA.STORE"
  WATERMARK_POSITION = "center_lower"
  ASPECT_RATIO = "9:16"

  normalizes :product_slug, :product_name, :objective, :marketing_angle, :aspect_ratio, :watermark_text, :watermark_position,
             :provider, :provider_job_id, :reference_image_url, :result_video_url, :watermarked_video_url, :error_message,
             with: ->(value) { value.to_s.strip.presence }

  validates :product_slug, :product_name, :reference_image_url, :higgsfield_prompt, presence: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 5, less_than_or_equal_to: 15 }
  validates :aspect_ratio, inclusion: { in: [ ASPECT_RATIO ] }
  validates :watermark_text, inclusion: { in: [ WATERMARK_TEXT ] }
  validates :watermark_position, inclusion: { in: [ WATERMARK_POSITION ] }
  validates :status, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: PROVIDERS }
  validate :reference_image_url_is_https
  validate :screen_texts_are_strings
  validate :hashtags_are_strings

  %w[pending_review approved rejected queued_for_generation generating generated failed].each do |status_name|
    define_method("#{status_name}?") { status == status_name }
  end

  def deletable_by_admin?
    status.in?(DELETABLE_STATUSES)
  end

  def approve!
    review!("approved")
  end

  def reject!
    review!("rejected")
  end

  def queueable_by_admin?
    approved? && generation_input_complete?
  end

  def generatable_by_admin?
    status.in?(%w[approved queued_for_generation failed]) && generation_input_complete?
  end

  def mark_queued_for_generation!
    with_lock do
      unless queueable_by_admin?
        errors.add(:status, "ne permet pas la mise en attente de génération")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: "queued_for_generation", queued_for_generation_at: Time.current)
    end
  end

  def start_generation!
    with_lock do
      unless generatable_by_admin?
        errors.add(:status, "ne permet pas le lancement de génération")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(
        status: "generating",
        generation_started_at: Time.current,
        provider_job_id: nil,
        raw_response: {},
        result_video_url: nil,
        error_message: nil,
        failed_at: nil,
        generated_at: nil
      )
    end
  end

  def apply_higgsfield_response!(response)
    with_lock do
      return unless generating?

      case response.status
      when "queued", "in_progress"
        update!(provider_job_id: response.request_id, raw_response: response.raw_response)
      when "completed"
        if response.video_url.present?
          update!(
            status: "generated",
            provider_job_id: response.request_id,
            raw_response: response.raw_response,
            result_video_url: response.video_url,
            generated_at: Time.current,
            error_message: nil
          )
        else
          fail_generation_without_lock!("Higgsfield a terminé la demande sans URL vidéo.", raw_response: response.raw_response, provider_job_id: response.request_id)
        end
      when "failed", "nsfw"
        fail_generation_without_lock!("Higgsfield a refusé ou échoué à générer cette vidéo.", raw_response: response.raw_response, provider_job_id: response.request_id)
      else
        fail_generation_without_lock!("Higgsfield a retourné un statut inconnu.", raw_response: response.raw_response, provider_job_id: response.request_id)
      end
    end
  end

  def mark_generation_failed!(message, raw_response: nil)
    with_lock do
      return unless generating?

      fail_generation_without_lock!(message, raw_response: raw_response)
    end
  end

  def destroy_by_admin!
    with_lock do
      unless deletable_by_admin?
        errors.add(:status, "ne permet pas la suppression")
        raise ActiveRecord::RecordInvalid, self
      end

      destroy!
    end
  end

  private

  def review!(new_status)
    with_lock do
      unless pending_review?
        errors.add(:status, "a déjà été traité")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: new_status, reviewed_at: Time.current)
    end
  end

  def generation_input_complete?
    higgsfield_prompt.present? && reference_image_url.present? && duration_seconds.present? && aspect_ratio.present?
  end

  def fail_generation_without_lock!(message, raw_response: nil, provider_job_id: nil)
    attributes = { status: "failed", error_message: message, failed_at: Time.current }
    attributes[:raw_response] = raw_response if raw_response
    attributes[:provider_job_id] = provider_job_id if provider_job_id
    update!(attributes)
  end

  def reference_image_url_is_https
    uri = URI.parse(reference_image_url.to_s)
    errors.add(:reference_image_url, "doit être une URL HTTPS valide") unless uri.is_a?(URI::HTTPS) && uri.host.present?
  rescue URI::InvalidURIError
    errors.add(:reference_image_url, "doit être une URL HTTPS valide")
  end

  def screen_texts_are_strings
    errors.add(:screen_texts, "doit être une liste de textes") unless array_of_strings?(screen_texts)
  end

  def hashtags_are_strings
    errors.add(:hashtags, "doit être une liste de hashtags") unless array_of_strings?(hashtags)
  end

  def array_of_strings?(value)
    value.is_a?(Array) && value.all? { |item| item.is_a?(String) }
  end
end

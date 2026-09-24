module Ai
  class VideoJobsController < ApplicationController
    skip_forgery_protection

    before_action :authenticate_ai_marketing!

    def create
      product = Product.visible.find_by(slug: video_job_params[:product_slug])
      return render json: { error: "Produit introuvable ou non publié." }, status: :unprocessable_entity if product.nil?

      video_job = MarketingVideoJob.new(
        video_job_params.merge(product_name: product.name, raw_request: video_job_params.to_h)
      )

      if video_job.save
        render json: { id: video_job.id, status: video_job.status }, status: :created
      else
        render json: { errors: video_job.errors.to_hash }, status: :unprocessable_entity
      end
    end

    private

    def authenticate_ai_marketing!
      expected_token = ENV.fetch("AI_MARKETING_API_TOKEN", "")
      bearer_token = request.authorization.to_s.delete_prefix("Bearer ").strip
      return if expected_token.present? && ActiveSupport::SecurityUtils.secure_compare(bearer_token, expected_token)

      head :unauthorized
    end

    def video_job_params
      params.permit(
        :product_slug, :objective, :marketing_angle, :hook, :script, :caption, :higgsfield_prompt,
        :duration_seconds, :aspect_ratio, :reference_image_url, :watermark_text, :watermark_position,
        screen_texts: [], hashtags: []
      )
    end
  end
end

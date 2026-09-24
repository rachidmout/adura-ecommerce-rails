class StripeWebhooksController < ApplicationController
  skip_forgery_protection

  def create
    event = Stripe::Webhook.construct_event(
      request.raw_post,
      request.headers["Stripe-Signature"],
      ENV.fetch("STRIPE_WEBHOOK_SECRET")
    )
    Payments::ProcessStripeEvent.new(event).call
    head :ok
  rescue KeyError
    Rails.logger.error("STRIPE_WEBHOOK_SECRET est absente")
    head :service_unavailable
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  rescue ActiveRecord::RecordNotUnique
    head :ok
  rescue StandardError => error
    Rails.logger.error("Webhook Stripe non traité: #{error.class}: #{error.message}")
    head :unprocessable_entity
  end
end

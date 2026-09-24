class ReconcileStockReservationsJob < ActiveJob::Base
  class StripeConfigurationError < StandardError; end

  queue_as :default

  # Stripe reste l'autorité pour l'expiration : on ne libère jamais une
  # réservation simplement parce que l'horloge locale a dépassé son délai.
  def perform
    ensure_stripe_configured!
    reconcile_pending_sessions
    reconcile_expired_sessions
  end

  private

  def ensure_stripe_configured!
    raise StripeConfigurationError, "STRIPE_SECRET_KEY est absente." if ENV["STRIPE_SECRET_KEY"].blank?
  end

  def reconcile_pending_sessions
    StockReservation.pending_session.where("created_at <= ?", 2.minutes.ago).find_each do |reservation|
      payment = reservation.payment
      order = payment.order
      Payments::CreateCheckoutSession.new(
        order: order,
        success_url: order_confirmation_url(order),
        cancel_url: order_confirmation_url(order, cancelled: 1)
      ).call
    rescue Stripe::StripeError, Payments::CreateCheckoutSession::OrderChanged
      # Une réponse réseau ambiguë conserve la réservation. La prochaine
      # exécution réutilise la même clé Stripe et ne sur-réserve rien.
      next
    end
  end

  def reconcile_expired_sessions
    StockReservation.active.where("expires_at <= ?", Time.current).find_each do |reservation|
      payment = reservation.payment
      session = Stripe::Checkout::Session.retrieve(payment.checkout_session_id)
      next unless session.status == "expired"

      Inventory::Reservations.release!(payment: payment, payment_status: :expired)
    rescue Stripe::StripeError
      next
    end
  end

  def order_confirmation_url(order, cancelled: nil)
    options = { host: ENV.fetch("APP_HOST", "https://example.com").delete_prefix("https://").delete_prefix("http://") }
    options[:cancelled] = cancelled if cancelled
    Rails.application.routes.url_helpers.order_confirmation_url(order.public_token, **options)
  end
end

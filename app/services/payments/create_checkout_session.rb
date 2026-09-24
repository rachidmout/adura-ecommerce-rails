module Payments
  class CreateCheckoutSession
    class ConfigurationError < StandardError; end
    class OrderChanged < StandardError; end

    def initialize(order:, success_url:, cancel_url:)
      @order = order
      @success_url = success_url
      @cancel_url = cancel_url
    end

    def call
      raise ConfigurationError, "STRIPE_SECRET_KEY est absente." if ENV["STRIPE_SECRET_KEY"].blank?

      payment, reservation = Inventory::Reservations.reserve!(order: order)
      @payment = payment
      return payment if reservation.active? && payment.checkout_session_id.present? && payment.checkout_url.present?

      session = Stripe::Checkout::Session.create(
        {
          mode: "payment",
          customer_email: order.email,
          line_items: stripe_line_items,
          discounts: stripe_discounts,
          success_url: success_url,
          cancel_url: cancel_url,
          expires_at: reservation.expires_at.to_i,
          locale: "fr",
          metadata: { order_id: order.id.to_s, payment_id: payment.id.to_s, public_token: order.public_token },
          payment_intent_data: { metadata: { order_id: order.id.to_s, payment_id: payment.id.to_s } }
        }.compact,
        { idempotency_key: "adura-checkout-payment-#{payment.id}" }
      )
      Inventory::Reservations.activate!(payment: payment, session: session)
    rescue Inventory::Reservations::Unavailable, Inventory::Reservations::InvalidState => error
      raise OrderChanged, error.message
    rescue Stripe::APIConnectionError, Stripe::APIError, Stripe::RateLimitError
      # L'état de la requête est inconnu : Stripe peut avoir créé la session.
      # La réservation pending_session est conservée et la même clé d'idempotence
      # sera réutilisée lors d'une reprise, sans sur-réserver le stock.
      raise
    rescue Stripe::StripeError
      Inventory::Reservations.release!(payment: payment, payment_status: :failed) if payment&.stock_reservation&.pending_session?
      raise
    end

    private

    attr_reader :order, :success_url, :cancel_url, :payment

    def stripe_line_items
      items = order.order_items.map do |item|
        {
          quantity: item.quantity,
          price_data: {
            currency: order.currency.downcase,
            unit_amount: item.unit_price_cents,
            product_data: { name: "#{item.brand_name} · #{item.product_name}", description: item.variant_label }
          }
        }
      end
      return items if order.shipping_cents.zero?

      items << {
        quantity: 1,
          price_data: {
            currency: order.currency.downcase,
            unit_amount: order.shipping_cents,
          product_data: { name: shipping_line_name }
        }
      }
    end

    def shipping_line_name
      [ order.shipping_method_name, order.shipping_carrier_name ].compact_blank.join(" — ").presence || "Livraison standard"
    end

    # Coupon Stripe éphémère : jamais réutilisé, jamais géré depuis le
    # dashboard Stripe. Rails reste seul maître de la validation/du calcul
    # du code promo (voir Promotions::ApplyPromoCode) — ce coupon ne sert
    # qu'à faire calculer par Stripe lui-même le bon amount_total, pour que
    # la vérification stricte de Payments::ProcessStripeEvent
    # (session.amount_total == order.total_cents) continue de passer sans
    # avoir à reproduire l'arithmétique de Stripe à la main.
    def stripe_discounts
      return nil unless order.discount_cents.positive?

      coupon_id = payment.stripe_coupon_id || create_coupon!
      [ { coupon: coupon_id } ]
    end

    def create_coupon!
      coupon = Stripe::Coupon.create(
        {
          amount_off: order.discount_cents,
          currency: order.currency.downcase,
          duration: "once",
          name: order.promo_code&.code
        },
        { idempotency_key: "adura-checkout-coupon-payment-#{payment.id}" }
      )
      payment.with_lock do
        payment.reload.stripe_coupon_id || begin
          payment.update!(stripe_coupon_id: coupon.id)
          coupon.id
        end
      end
    end
  end
end

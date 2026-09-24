module Payments
  class ProcessStripeEvent
    class StockConflict < StandardError; end

    def initialize(stripe_event)
      @stripe_event = stripe_event
    end

    def call
      event_record = PaymentEvent.create_or_find_by!(stripe_event_id: stripe_event.id) do |record|
        record.event_type = stripe_event.type
        record.payload_json = stripe_event.to_hash
      end
      return event_record if event_record.processed? || event_record.ignored?

      case stripe_event.type
      when "checkout.session.completed", "checkout.session.async_payment_succeeded"
        process_completed_checkout(event_record)
      when "checkout.session.expired", "checkout.session.async_payment_failed"
        process_failed_checkout(event_record)
      else
        event_record.update!(status: :ignored, processed_at: Time.current)
      end
      event_record
    rescue StandardError => error
      event_record&.update_columns(status: "failed", error_message: error.message.truncate(500), processed_at: Time.current)
      raise
    end

    private

    attr_reader :stripe_event

    def process_completed_checkout(event_record)
      session = stripe_event.data.object
      payment = Payment.find_by!(checkout_session_id: session.id)
      event_record.update!(payment: payment)

      if stripe_event.type == "checkout.session.completed" && session.payment_status != "paid"
        event_record.update!(status: :processed, processed_at: Time.current)
        return
      end

      order, = Inventory::Reservations.consume!(payment: payment) do |order, locked_payment|
        raise StockConflict, "Le montant Stripe ne correspond pas à la commande." unless session.amount_total == order.total_cents
        raise StockConflict, "La devise Stripe ne correspond pas à la commande." unless session.currency.to_s.upcase == order.currency

        previous_status = order.status
        order.update!(status: :paid, paid_at: Time.current, stock_decremented_at: Time.current)
        locked_payment.update!(status: :succeeded, payment_intent_id: session.payment_intent)
        order.order_status_events.create!(from_status: previous_status, to_status: order.status, source: "stripe", note: stripe_event.id)
        event_record.update!(status: :processed, processed_at: Time.current)
        OrderMailer.with(order: order).confirmation.deliver_later
      end
      event_record.update!(status: :processed, processed_at: Time.current) unless event_record.processed?
    end

    def process_failed_checkout(event_record)
      session = stripe_event.data.object
      payment = Payment.find_by(checkout_session_id: session.id)
      if payment
        Inventory::Reservations.release!(
          payment: payment,
          payment_status: stripe_event.type.include?("expired") ? :expired : :failed
        )
      end
      event_record.update!(payment: payment, status: :processed, processed_at: Time.current)
    end
  end
end

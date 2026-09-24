module Inventory
  class Reservations
    class Unavailable < StandardError; end
    class InvalidState < StandardError; end

    SESSION_LIFETIME = 30.minutes

    class << self
      # La réservation est faite avant l'appel réseau Stripe, sous verrous
      # PostgreSQL. Ainsi une URL Checkout n'est jamais remise à une cliente
      # tant que tous les articles de son panier ne sont pas bloqués.
      def reserve!(order:)
        Order.transaction do
          order = Order.lock.find(order.id)
          raise Unavailable, "Cette commande ne peut plus être payée." unless order.payable?

          payment = order.payments.pending.order(created_at: :desc).first ||
            order.payments.create!(amount_cents: order.total_cents, currency: order.currency, status: :pending)
          reservation = payment.stock_reservation
          return [ payment, reservation ] if reservation&.pending_session? || reservation&.active?

          items_by_variant_id = order.order_items.group_by(&:product_variant_id)
          raise Unavailable, "Une variante de la commande n’existe plus." if items_by_variant_id.key?(nil)

          variants = locked_variants(items_by_variant_id.keys)
          validate_lines!(items_by_variant_id, variants)

          reservation = payment.create_stock_reservation!(state: :pending_session, expires_at: SESSION_LIFETIME.from_now)
          items_by_variant_id.each do |variant_id, order_items|
            quantity = order_items.sum(&:quantity)
            reservation.stock_reservation_items.create!(product_variant_id: variant_id, quantity: quantity)
            variant = variants.fetch(variant_id)
            variant.update!(reserved_stock_quantity: variant.reserved_stock_quantity + quantity)
          end

          [ payment, reservation ]
        end
      end

      def activate!(payment:, session:)
        Order.transaction do
          order = Order.lock.find(payment.order_id)
          payment = order.payments.lock.find(payment.id)
          reservation = payment.stock_reservation.lock!
          return payment if reservation.active? && payment.checkout_session_id == session.id
          raise InvalidState, "La réservation n’est plus active." unless reservation.pending_session?

          payment.update!(checkout_session_id: session.id, checkout_url: session.url, checkout_expires_at: Time.zone.at(session.expires_at))
          reservation.update!(state: :active, activated_at: Time.current)
          payment
        end
      end

      def release!(payment:, payment_status:)
        Order.transaction do
          order = Order.lock.find(payment.order_id)
          payment = order.payments.lock.find(payment.id)
          reservation = payment.stock_reservation.lock!
          return payment if reservation.released? || reservation.consumed?

          locked_reservation_variants(reservation).each do |variant, item|
            variant.update!(reserved_stock_quantity: variant.reserved_stock_quantity - item.quantity)
          end
          reservation.update!(state: :released, released_at: Time.current)
          payment.update!(status: payment_status)
          payment
        end
      end

      def consume!(payment:)
        Order.transaction do
          order = Order.lock.find(payment.order_id)
          payment = order.payments.lock.find(payment.id)
          reservation = payment.stock_reservation.lock!
          return [ order, payment ] if order.paid? || order.shipped?
          return [ order, payment ] if reservation.consumed? && (order.paid? || order.shipped?)
          raise InvalidState, "La réservation a déjà été libérée." if reservation.released?
          raise InvalidState, "La session de paiement n’est pas encore active." unless reservation.active?

          yield order, payment if block_given?

          locked_reservation_variants(reservation).each do |variant, item|
            if item.quantity > variant.reserved_stock_quantity || item.quantity > variant.stock_quantity
              raise Unavailable, "Stock insuffisant pour #{variant.sku}."
            end

            variant.update!(
              stock_quantity: variant.stock_quantity - item.quantity,
              reserved_stock_quantity: variant.reserved_stock_quantity - item.quantity
            )
          end
          reservation.update!(state: :consumed, consumed_at: Time.current)
          [ order, payment ]
        end
      end

      private

      def locked_variants(ids)
        ProductVariant.includes(:product).where(id: ids).order(:id).lock.index_by(&:id)
      end

      def locked_reservation_variants(reservation)
        items = reservation.stock_reservation_items.order(:product_variant_id).to_a
        variants = ProductVariant.where(id: items.map(&:product_variant_id)).order(:id).lock.index_by(&:id)
        raise Unavailable, "Une variante réservée n’existe plus." unless variants.size == items.size

        items.map { |item| [ variants.fetch(item.product_variant_id), item ] }
      end

      def validate_lines!(items_by_variant_id, variants)
        raise Unavailable, "Une variante de la commande n’existe plus." unless variants.size == items_by_variant_id.size

        items_by_variant_id.each do |variant_id, order_items|
          variant = variants.fetch(variant_id)
          quantity = order_items.sum(&:quantity)
          raise Unavailable, "#{variant.product.name} n’est plus disponible." unless variant.available?
          raise Unavailable, "Le prix de #{variant.product.name} a changé." unless order_items.all? { |item| item.unit_price_cents == variant.price_cents }
          raise Unavailable, "Le stock de #{variant.product.name} est insuffisant." if quantity > variant.available_stock_quantity
        end
      end
    end
  end
end

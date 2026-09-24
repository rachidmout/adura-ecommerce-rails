module Checkout
  class CreateOrder
    class EmptyCart < StandardError; end
    class StockChanged < StandardError; end
    class InvalidPromoCode < StandardError; end
    class InvalidShippingMethod < StandardError; end
    class ShippingUnavailable < StandardError; end
    class RelayPointRequired < StandardError; end
    class RelayPointUnavailable < StandardError; end

    def initialize(cart:, customer_params:, terms_accepted:, promo_code: nil, shipping_method_id: nil, relay_point_id: nil, shop_setting: ShopSetting.current)
      @cart = cart
      @customer_params = customer_params
      @terms_accepted = ActiveModel::Type::Boolean.new.cast(terms_accepted)
      @promo_code = promo_code.presence
      @shipping_method_id = shipping_method_id.presence
      @relay_point_id = relay_point_id.presence
      @shop_setting = shop_setting
    end

    def call
      raise EmptyCart, I18n.t("checkouts.errors.empty_cart") if cart.empty?

      Order.transaction do
        lines = locked_and_validated_lines
        subtotal_cents = lines.sum(&:line_total_cents)
        promo_result = resolve_promo_code(lines, subtotal_cents)
        discount_cents = promo_result&.discount_cents || 0
        shipping = shipping_snapshot(lines, subtotal_cents)
        relay_point = relay_point_snapshot

        order = Order.create!(
          customer_params.merge(
            status: :pending,
            promo_code: promo_result&.promo_code,
            subtotal_cents: subtotal_cents,
            shipping_cents: shipping.fetch(:shipping_cents),
            discount_cents: discount_cents,
            total_cents: subtotal_cents + shipping.fetch(:shipping_cents) - discount_cents,
            currency: shop_setting.currency,
            **shipping,
            terms_accepted_at: terms_accepted_at
          )
        )
        create_relay_point_snapshot!(order, relay_point) if relay_point

        lines.each do |line|
          variant = line.variant
          order.order_items.create!(
            product_variant: variant,
            product_name: variant.product.name,
            brand_name: variant.product.brand.name,
            variant_label: variant.label,
            sku: variant.sku,
            volume_ml: variant.volume_ml,
            unit_price_cents: variant.price_cents,
            quantity: line.quantity,
            line_total_cents: line.line_total_cents
          )
        end
        order.order_status_events.create!(to_status: order.status, source: "checkout", note: "Commande créée avant paiement")
        order
      end
    end

    private

    attr_reader :cart, :customer_params, :terms_accepted, :promo_code, :shipping_method_id, :relay_point_id, :shop_setting

    def locked_and_validated_lines
      cart.lines.map do |line|
        variant = ProductVariant.lock.includes(product: :brand).find(line.variant.id)
        raise StockChanged, I18n.t("checkouts.errors.product_unavailable", product: variant.product.name) unless variant.available?
        raise StockChanged, I18n.t("checkouts.errors.insufficient_stock", product: variant.product.name) if line.quantity > variant.stock_quantity

        Cart::Line.new(variant: variant, quantity: line.quantity)
      end
    end

    # Dernière validation, autoritaire : à partir des lignes verrouillées en
    # base (jamais du panier en session), donc impossible à falsifier depuis
    # le navigateur. Si le code n'est plus valide entre l'aperçu affiché sur
    # le panier et cet instant (limite atteinte entre-temps, par exemple),
    # la commande n'est pas créée.
    def resolve_promo_code(lines, subtotal_cents)
      return nil if promo_code.blank?

      result = Promotions::ApplyPromoCode.new(
        code: promo_code,
        subtotal_cents: subtotal_cents,
        product_ids: lines.map { |line| line.variant.product_id },
        email: customer_params[:email]
      ).call
      raise InvalidPromoCode, result.error_message unless result.success?

      result
    end

    def shipping_snapshot(lines, subtotal_cents)
      return legacy_shipping_snapshot(subtotal_cents) unless ShippingMethodsFeature.enabled?

      if customer_params[:country_code].blank? || shipping_method_id.blank?
        raise InvalidShippingMethod, I18n.t("checkouts.new.select_country_and_shipping_method")
      end

      quote = Shipping::QuoteCalculator.new(
        country_code: customer_params[:country_code], lines: lines, subtotal_cents: subtotal_cents, shop_setting: shop_setting
      ).call
      selected = quote.methods.find { |method| method.shipping_method_id == shipping_method_id.to_i }
      raise InvalidShippingMethod, I18n.t("checkouts.errors.invalid_shipping_method") unless selected

      @selected_shipping_method = selected
      @shipping_package_weight_grams = quote.package_weight_grams

      {
        shipping_cents: selected.price_cents,
        shipping_rate_snapshot_cents: selected.normal_price_cents,
        free_shipping_threshold_snapshot_cents: selected.free_shipping_threshold_cents,
        shipping_zone_name: selected.shipping_zone_name,
        shipping_method_name: selected.name,
        shipping_carrier_name: selected.carrier_name,
        shipping_method_kind: selected.kind,
        shipping_provider: selected.provider,
        shipping_provider_carrier_code: selected.provider_carrier_code,
        shipping_weight_grams: quote.package_weight_grams
      }
    rescue Shipping::QuoteCalculator::Error => error
      Rails.logger.warn("Configuration livraison indisponible à la commande: #{error.class}: #{error.message}")
      raise ShippingUnavailable, I18n.t("checkouts.errors.shipping_unavailable")
    end

    def legacy_shipping_snapshot(subtotal_cents)
      {
        shipping_cents: shop_setting.shipping_for(subtotal_cents),
        shipping_rate_snapshot_cents: shop_setting.shipping_rate_cents,
        free_shipping_threshold_snapshot_cents: shop_setting.free_shipping_threshold_cents
      }
    end

    def relay_point_snapshot
      return unless selected_shipping_method&.kind == "pickup_point"
      raise RelayPointRequired, I18n.t("checkouts.errors.relay_point_required") if relay_point_id.blank?

      point = Shipping::PickupPointSearch.new(
        provider: selected_shipping_method.provider,
        provider_carrier_code: selected_shipping_method.provider_carrier_code,
        carrier_name: selected_shipping_method.carrier_name,
        country_code: customer_params[:country_code],
        package_weight_grams: shipping_package_weight_grams
      ).find(relay_point_id)
      {
        carrier: point.carrier,
        relay_id: point.relay_id,
        relay_name: point.name,
        relay_address_line1: point.address_line1,
        relay_address_line2: point.address_line2,
        relay_postal_code: point.postal_code,
        relay_city: point.city,
        relay_country: point.country_code,
        relay_opening_hours: point.opening_hours,
        relay_raw_data: point.raw_data
      }
    rescue Shipping::PickupPointSearch::NotFound, Shipping::PickupPointSearch::Unavailable => error
      raise RelayPointUnavailable, error.message
    end

    def create_relay_point_snapshot!(order, snapshot)
      order.create_relay_point!(snapshot)
    end

    attr_reader :selected_shipping_method, :shipping_package_weight_grams

    def terms_accepted_at
      unless terms_accepted
        invalid_order = Order.new
        invalid_order.errors.add(:base, I18n.t("checkouts.errors.terms_required"))
        raise ActiveRecord::RecordInvalid, invalid_order
      end

      Time.current
    end
  end
end

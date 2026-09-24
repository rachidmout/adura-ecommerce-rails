class CheckoutsController < ApplicationController
  include PromoCodePreview

  def new
    redirect_to cart_path, alert: t("checkouts.errors.empty_cart") if current_cart.empty?
    # Le choix du pays détermine les méthodes et le montant de livraison : il
    # ne doit jamais être déduit de l'ordre, non garanti, d'une requête SQL.
    # On neutralise aussi le défaut historique FR du schéma pour demander un
    # choix explicite lorsque le moteur multi-pays est actif.
    @order = Order.new(country_code: Checkout::ShippingMethodsFeature.enabled? ? nil : "FR")
    prepare_summary
  end

  def create
    order = Checkout::CreateOrder.new(
      cart: current_cart,
      customer_params: order_params.to_h.symbolize_keys,
      terms_accepted: params[:terms_accepted],
      promo_code: session[:promo_code],
      shipping_method_id: params[:shipping_method_id],
      relay_point_id: params[:relay_point_id]
    ).call

    payment = Payments::CreateCheckoutSession.new(
      order: order,
      success_url: order_confirmation_url(order.public_token),
      cancel_url: order_confirmation_url(order.public_token, cancelled: 1)
    ).call
    current_cart.clear
    session.delete(:promo_code)
    redirect_to payment.checkout_url, allow_other_host: true
  rescue Payments::CreateCheckoutSession::ConfigurationError => error
    Rails.logger.warn("Stripe non configuré: #{error.message}")
    current_cart.clear if order.present?
    redirect_to order_confirmation_path(order.public_token), alert: t("checkouts.errors.stripe_not_configured")
  rescue Stripe::StripeError => error
    Rails.logger.error("Stripe indisponible pendant la création du paiement: #{error.class}: #{error.message}")
    current_cart.clear if order.present?
    redirect_to order_confirmation_path(order.public_token), alert: t("checkouts.errors.stripe_unavailable")
  rescue Checkout::CreateOrder::InvalidShippingMethod, Checkout::CreateOrder::ShippingUnavailable, Checkout::CreateOrder::RelayPointRequired, Checkout::CreateOrder::RelayPointUnavailable => error
    @order = Order.new(order_params)
    @order.errors.add(:base, error.message)
    prepare_summary
    render :new, status: :unprocessable_entity
  rescue Checkout::CreateOrder::EmptyCart, Checkout::CreateOrder::StockChanged, Checkout::CreateOrder::InvalidPromoCode, Payments::CreateCheckoutSession::OrderChanged => error
    redirect_to cart_path, alert: error.message
  rescue ActiveRecord::RecordInvalid => error
    @order = Order.new(order_params)
    error.record.errors.each { |validation_error| @order.errors.add(validation_error.attribute, validation_error.message) }
    @order.errors.add(:base, error.message) if @order.errors.empty?
    prepare_summary
    render :new, status: :unprocessable_entity
  end

  def shipping_options
    return head :not_found unless Checkout::ShippingMethodsFeature.enabled?

    @order = Order.new(checkout_order_params)
    @order.country_code = params[:country_code] if params[:country_code].present?
    prepare_summary
    respond_to do |format|
      format.json do
        if @shipping_error.present?
          render json: { methods: [], error: @shipping_error }, status: :unprocessable_entity
        else
          render json: shipping_options_json
        end
      end
      format.html { render :new, status: @shipping_error.present? ? :unprocessable_entity : :ok }
    end
  end

  def relay_points
    return head :not_found unless Checkout::ShippingMethodsFeature.enabled?

    shipping_method = ShippingMethod.where(active: true).find_by(id: params[:shipping_method_id])
    return render json: { points: [], error: t("checkouts.errors.pickup_delivery_required") }, status: :unprocessable_entity unless shipping_method&.pickup_point?

    lines = current_cart.lines
    quote = Shipping::QuoteCalculator.new(
      country_code: params[:country_code], lines: lines, subtotal_cents: current_cart.subtotal_cents
    ).call
    selected = quote.methods.find { |method| method.shipping_method_id == shipping_method.id }
    return render json: { points: [], error: t("checkouts.errors.invalid_shipping_method") }, status: :unprocessable_entity unless selected

    points = Shipping::PickupPointSearch.new(
      provider: shipping_method.provider,
      provider_carrier_code: shipping_method.provider_carrier_code,
      carrier_name: shipping_method.carrier_name,
      country_code: params[:country_code],
      postal_code: params[:postal_code],
      city: params[:city],
      package_weight_grams: quote.package_weight_grams
    ).search
    if points.empty?
      render json: { points: [], message: t("checkouts.errors.no_relay_points") }
    else
      render json: { points: points.map(&:to_h) }
    end
  rescue Shipping::QuoteCalculator::Error, Shipping::PickupPointSearch::Error => error
    render json: { points: [], error: pickup_point_error_message(error) }, status: :unprocessable_entity
  end

  private

  def order_params
    params.require(:order).permit(:email, :first_name, :last_name, :phone, :address_line1, :address_line2, :postal_code, :city, :country_code)
  end

  def checkout_order_params
    params.fetch(:order, {}).permit(:email, :first_name, :last_name, :phone, :address_line1, :address_line2, :postal_code, :city, :country_code)
  end

  def prepare_summary
    @checkout_country_codes = Checkout::SupportedCountries.codes
    @lines = current_cart.lines
    @subtotal_cents = current_cart.subtotal_cents
    apply_promo_code_preview(lines: @lines, subtotal_cents: @subtotal_cents)
    if Checkout::ShippingMethodsFeature.enabled?
      @shipping_unavailable = false
      if @order.country_code.blank?
        @shipping_error = I18n.t("checkouts.new.select_country_and_shipping_method")
        @shipping_unavailable = true
        @shipping_cents = 0
      else
        begin
          @shipping_quote = Shipping::QuoteCalculator.new(
            country_code: @order.country_code,
            lines: @lines,
            subtotal_cents: @subtotal_cents
          ).call
          @selected_shipping_method_id = params[:shipping_method_id].presence&.to_i
          @selected_shipping_method = @shipping_quote.methods.find { |method| method.shipping_method_id == @selected_shipping_method_id }
          @selected_shipping_method ||= @shipping_quote.methods.first unless @selected_shipping_method_id
          @shipping_error = t("checkouts.errors.invalid_shipping_method") if @selected_shipping_method_id && @selected_shipping_method.nil?
          @shipping_unavailable = @selected_shipping_method.nil?
          @shipping_cents = @selected_shipping_method&.price_cents || 0
        rescue Shipping::QuoteCalculator::Error => error
          @shipping_error = shipping_error_message(error)
          @shipping_unavailable = true
          @shipping_cents = 0
        end
      end
    else
      @shipping_cents = ShopSetting.current.shipping_for(@subtotal_cents)
    end
    @total_cents = @subtotal_cents + @shipping_cents - @discount_cents
  end

  def shipping_options_json
    {
      methods: @shipping_quote.methods.map { |method| method.to_h.slice(:shipping_method_id, :name, :carrier_name, :kind, :normal_price_cents, :price_cents, :free_shipping) },
      subtotal_cents: @subtotal_cents,
      discount_cents: @discount_cents
    }
  end

  def shipping_error_message(error)
    case error
    when Shipping::QuoteCalculator::MissingVariantWeight then t("checkouts.errors.missing_variant_weight")
    when Shipping::QuoteCalculator::DestinationUnsupported then t("checkouts.errors.destination_unsupported")
    when Shipping::QuoteCalculator::NoShippingMethodAvailable, Shipping::QuoteCalculator::NoRateForWeight then t("checkouts.errors.no_shipping_method")
    else
      Rails.logger.warn("Configuration livraison invalide: #{error.class}: #{error.message}")
      t("checkouts.errors.shipping_unavailable")
    end
  end

  def pickup_point_error_message(error)
    return t("checkouts.errors.relay_point_unavailable") if error.is_a?(Shipping::PickupPointSearch::NotFound)

    t("checkouts.new.relay_unavailable")
  end
end

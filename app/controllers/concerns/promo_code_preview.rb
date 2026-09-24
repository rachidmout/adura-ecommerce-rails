module PromoCodePreview
  extend ActiveSupport::Concern

  private

  # Aperçu affiché sur le panier/la commande : revalide le code stocké en
  # session à chaque affichage. Ce n'est qu'un aperçu — la validation qui
  # compte est refaite une dernière fois côté serveur dans
  # Checkout::CreateOrder au moment de la création de la commande.
  def apply_promo_code_preview(lines:, subtotal_cents:)
    @promo_code_input = session[:promo_code]
    @discount_cents = 0
    return if @promo_code_input.blank?

    result = Promotions::ApplyPromoCode.new(
      code: @promo_code_input,
      subtotal_cents: subtotal_cents,
      product_ids: lines.map { |line| line.product.id }
    ).call

    if result.success?
      @promo_code_applied = result.promo_code
      @discount_cents = result.discount_cents
      if session.delete(:analytics_promo_event_pending)
        @analytics_promo_event = {
          promo_applied: true,
          discount_type: @promo_code_applied.discount_type,
          discount_value: @discount_cents / 100.0
        }
      end
    else
      session.delete(:analytics_promo_event_pending)
      @promo_code_error = result.error_message
    end
  end
end

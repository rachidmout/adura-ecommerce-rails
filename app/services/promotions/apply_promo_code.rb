module Promotions
  # Revalide un code promo côté serveur à partir de données déjà connues de
  # Rails (sous-total recalculé depuis les prix en base, pas depuis le
  # panier/le navigateur). Utilisé à la fois pour l'aperçu (panier, page de
  # commande) et pour la validation finale dans Checkout::CreateOrder — ne
  # lève jamais d'exception elle-même, un code invalide est un résultat
  # normal, pas une erreur système.
  class ApplyPromoCode
    Result = Struct.new(:success?, :promo_code, :discount_cents, :error_message, keyword_init: true)

    def initialize(code:, subtotal_cents:, product_ids: [], email: nil)
      @code = code.to_s.strip
      @subtotal_cents = subtotal_cents
      @product_ids = Array(product_ids)
      @email = email.to_s.strip.downcase.presence
    end

    def call
      return failure(I18n.t("promo_code.errors.blank")) if code.blank?

      promo_code = PromoCode.active_now.find_by("lower(code) = ?", code.downcase)
      return failure(I18n.t("promo_code.errors.invalid")) unless promo_code
      return failure(I18n.t("promo_code.errors.usage_limit")) if max_uses_reached?(promo_code)
      return failure(I18n.t("promo_code.errors.customer_limit")) if max_uses_per_customer_reached?(promo_code)
      return failure(min_order_message(promo_code)) if below_minimum_order?(promo_code)
      return failure(I18n.t("promo_code.errors.out_of_scope")) if out_of_scope?(promo_code)

      success(promo_code)
    end

    private

    attr_reader :code, :subtotal_cents, :product_ids, :email

    def max_uses_reached?(promo_code)
      promo_code.max_uses.present? && promo_code.uses_count >= promo_code.max_uses
    end

    def max_uses_per_customer_reached?(promo_code)
      return false if email.blank? || promo_code.max_uses_per_customer.blank?

      promo_code.uses_count_for(email) >= promo_code.max_uses_per_customer
    end

    def below_minimum_order?(promo_code)
      promo_code.min_order_cents.present? && subtotal_cents < promo_code.min_order_cents
    end

    def min_order_message(promo_code)
      euros, cents = promo_code.min_order_cents.divmod(100)
      I18n.t("promo_code.errors.minimum_order", euros: euros, cents: format("%02d", cents))
    end

    def out_of_scope?(promo_code)
      return false unless promo_code.scoped?

      product_ids.none? { |id| promo_code.applies_to_product_id?(id) }
    end

    def success(promo_code)
      Result.new(success?: true, promo_code: promo_code, discount_cents: promo_code.discount_for(subtotal_cents), error_message: nil)
    end

    def failure(message)
      Result.new(success?: false, promo_code: nil, discount_cents: 0, error_message: message)
    end
  end
end

class CartsController < ApplicationController
  include PromoCodePreview

  def show
    @lines = current_cart.lines
    @shop_setting = ShopSetting.current
    @subtotal_cents = current_cart.subtotal_cents
    apply_promo_code_preview(lines: @lines, subtotal_cents: @subtotal_cents)
    @shipping_pending = Checkout::ShippingMethodsFeature.enabled?
    @shipping_cents = @shipping_pending ? 0 : @shop_setting.shipping_for(@subtotal_cents)
    @total_cents = @subtotal_cents + @shipping_cents - @discount_cents
  end
end

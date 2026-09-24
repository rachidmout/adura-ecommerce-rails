class PromoCodesController < ApplicationController
  # Ne valide rien ici : on stocke juste le code saisi en session, la
  # validation réelle se fait à chaque affichage (voir PromoCodePreview)
  # et une dernière fois, de façon autoritaire, à la création de la
  # commande (Checkout::CreateOrder).
  def create
    session[:promo_code] = params[:code].to_s.strip.presence
    if session[:promo_code].present?
      session[:analytics_promo_event_pending] = true
    else
      session.delete(:analytics_promo_event_pending)
    end
    redirect_back fallback_location: cart_path
  end

  def destroy
    session.delete(:promo_code)
    session.delete(:analytics_promo_event_pending)
    redirect_back fallback_location: cart_path
  end
end

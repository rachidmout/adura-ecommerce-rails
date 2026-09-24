class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  protect_from_forgery with: :exception

  around_action :switch_locale
  helper_method :current_cart, :cart_count

  private

  # Toute URL publique commence par un préfixe de langue optionnel
  # (/en/parfums, /parfums pour le français). On lit ce préfixe, on
  # l'applique le temps de la requête (I18n.with_locale), puis Rails revient
  # automatiquement à la langue par défaut pour la requête suivante — on n'a
  # pas besoin de le stocker en session.
  def switch_locale(&action)
    locale = params[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  # Utilisé par les helpers de route (product_path, root_path, etc.) pour
  # garder automatiquement le préfixe de langue courant dans chaque lien
  # généré, sans avoir à le répéter partout dans les vues.
  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end

  def current_cart
    @current_cart ||= Cart.new(session)
  end

  def cart_count
    current_cart.count
  end
end

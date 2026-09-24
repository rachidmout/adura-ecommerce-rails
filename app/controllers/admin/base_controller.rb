module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_admin
    helper_method :current_admin_user

    private

    def current_admin_user
      @current_admin_user ||= AdminUser.active.find_by(id: session[:admin_user_id])
    end

    def require_admin
      redirect_to admin_login_path, alert: "Connectez-vous pour accéder à l’administration." unless current_admin_user
    end

    def euro_cents(value, attribute:)
      return nil if value.blank?

      cents = ProductVariant.cents_from_euros(value)
      return cents if cents && !cents.negative?

      raise ArgumentError, "#{attribute} doit être un montant positif ou nul."
    end
  end
end

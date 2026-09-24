module Admin
  class SessionsController < ApplicationController
    layout "admin"

    def new
    end

    def create
      admin_user = AdminUser.active.find_by(email: params[:email].to_s.strip.downcase)
      if admin_user&.authenticate(params[:password])
        reset_session
        session[:admin_user_id] = admin_user.id
        admin_user.update_column(:last_signed_in_at, Time.current)
        redirect_to admin_root_path, notice: "Connexion réussie."
      else
        flash.now[:alert] = "E-mail ou mot de passe incorrect."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      reset_session
      redirect_to admin_login_path, notice: "Vous êtes déconnecté."
    end
  end
end

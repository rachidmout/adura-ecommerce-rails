module Admin
  class ShippingMethodsController < BaseController
    before_action :set_zone
    before_action :set_shipping_method, only: %i[edit update destroy activate deactivate]

    def new
      @shipping_method = @zone.shipping_methods.new(active: false)
    end

    def create
      @shipping_method = @zone.shipping_methods.new
      assign_attributes(@shipping_method)
      if @shipping_method.save
        redirect_to admin_shipping_zone_path(@zone), notice: "Méthode de livraison créée."
      else
        render :new, status: :unprocessable_entity
      end
    rescue ArgumentError => error
      @shipping_method.errors.add(:free_shipping_threshold_cents, error.message)
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      assign_attributes(@shipping_method)
      if @shipping_method.save
        redirect_to admin_shipping_zone_path(@zone), notice: "Méthode de livraison enregistrée."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ArgumentError => error
      @shipping_method.errors.add(:free_shipping_threshold_cents, error.message)
      render :edit, status: :unprocessable_entity
    end

    def activate
      @shipping_method.update!(active: true)
      redirect_to admin_shipping_zone_path(@zone), notice: "Méthode activée."
    end

    def deactivate
      @shipping_method.update!(active: false)
      redirect_to admin_shipping_zone_path(@zone), notice: "Méthode désactivée."
    end

    def destroy
      if @shipping_method.destroy
        redirect_to admin_shipping_zone_path(@zone), notice: "Méthode supprimée."
      else
        redirect_to admin_shipping_zone_path(@zone), alert: "Cette méthode ne peut pas être supprimée tant qu’elle contient des tarifs."
      end
    end

    private

    def set_zone
      @zone = ShippingZone.find(params[:shipping_zone_id])
    end

    def set_shipping_method
      @shipping_method = @zone.shipping_methods.find(params[:id])
    end

    def assign_attributes(shipping_method)
      attributes = method_params.to_h
      threshold = attributes.delete("free_shipping_threshold_euros")
      shipping_method.assign_attributes(attributes)
      shipping_method.free_shipping_threshold_cents = euro_cents(threshold, attribute: "Le seuil de gratuité")
    end

    def method_params
      params.require(:shipping_method).permit(:name, :carrier_name, :kind, :provider, :provider_carrier_code, :provider_method_id_override, :active, :free_shipping_threshold_euros)
    end
  end
end

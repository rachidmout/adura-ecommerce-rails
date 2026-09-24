module Admin
  class ShippingZonesController < BaseController
    before_action :set_zone, only: %i[show edit update destroy activate deactivate]

    def index
      @zones = ShippingZone.includes(:shipping_zone_countries, :shipping_methods).order(:name)
    end

    def show
      @countries = @zone.shipping_zone_countries.order(:country_code)
      @methods = @zone.shipping_methods.includes(:shipping_rates).order(:name)
    end

    def new
      @zone = ShippingZone.new(active: false)
    end

    def create
      @zone = ShippingZone.new(zone_params)
      if @zone.save
        redirect_to admin_shipping_zone_path(@zone), notice: "Zone de livraison créée."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @zone.update(zone_params)
        redirect_to admin_shipping_zone_path(@zone), notice: "Zone de livraison enregistrée."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def activate
      @zone.update!(active: true)
      redirect_to admin_shipping_zone_path(@zone), notice: "Zone activée."
    end

    def deactivate
      @zone.update!(active: false)
      redirect_to admin_shipping_zone_path(@zone), notice: "Zone désactivée."
    end

    def destroy
      if @zone.destroy
        redirect_to admin_shipping_zones_path, notice: "Zone supprimée."
      else
        redirect_to admin_shipping_zone_path(@zone), alert: "Cette zone ne peut pas être supprimée tant qu’elle contient des pays ou des méthodes."
      end
    end

    private

    def set_zone
      @zone = ShippingZone.find(params[:id])
    end

    def zone_params
      params.require(:shipping_zone).permit(:name, :active)
    end
  end
end

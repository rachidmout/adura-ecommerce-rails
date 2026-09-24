module Admin
  class ShippingZoneCountriesController < BaseController
    before_action :set_zone

    def create
      country = @zone.shipping_zone_countries.new(country_params)
      if country.save
        redirect_to admin_shipping_zone_path(@zone), notice: "Pays ajouté à la zone."
      else
        redirect_to admin_shipping_zone_path(@zone), alert: country.errors.full_messages.to_sentence
      end
    end

    def destroy
      @zone.shipping_zone_countries.find(params[:id]).destroy!
      redirect_to admin_shipping_zone_path(@zone), notice: "Pays retiré de la zone."
    end

    private

    def set_zone
      @zone = ShippingZone.find(params[:shipping_zone_id])
    end

    def country_params
      params.require(:shipping_zone_country).permit(:country_code)
    end
  end
end

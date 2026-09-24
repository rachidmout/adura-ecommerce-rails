module Admin
  class ShippingConfigurationsController < BaseController
    def show
      @setting = ShopSetting.current
      @zones = ShippingZone.includes(:shipping_zone_countries, :shipping_methods).order(:name)
    end

    def packaging
      setting = ShopSetting.current
      setting.update!(packaging_params)
      redirect_to admin_shipping_configuration_path, notice: "Poids d’emballage enregistré."
    rescue ActiveRecord::RecordInvalid => error
      @setting = error.record
      @zones = ShippingZone.includes(:shipping_zone_countries, :shipping_methods).order(:name)
      render :show, status: :unprocessable_entity
    end

    private

    def packaging_params
      params.require(:shop_setting).permit(:base_packaging_weight_grams)
    end
  end
end

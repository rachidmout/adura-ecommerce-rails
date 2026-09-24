module Admin
  class ShippingRatesController < BaseController
    before_action :set_zone
    before_action :set_shipping_method
    before_action :set_rate, only: %i[edit update destroy]

    def new
      @rate = @shipping_method.shipping_rates.new(active: false)
    end

    def create
      @rate = @shipping_method.shipping_rates.new
      assign_attributes(@rate)
      if @rate.save
        redirect_to admin_shipping_zone_path(@zone), notice: "Tranche tarifaire créée."
      else
        render :new, status: :unprocessable_entity
      end
    rescue ArgumentError => error
      @rate.errors.add(:price_cents, error.message)
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      assign_attributes(@rate)
      if @rate.save
        redirect_to admin_shipping_zone_path(@zone), notice: "Tranche tarifaire enregistrée."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ArgumentError => error
      @rate.errors.add(:price_cents, error.message)
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @rate.destroy!
      redirect_to admin_shipping_zone_path(@zone), notice: "Tranche tarifaire supprimée."
    end

    private

    def set_zone
      @zone = ShippingZone.find(params[:shipping_zone_id])
    end

    def set_shipping_method
      @shipping_method = @zone.shipping_methods.find(params[:shipping_method_id])
    end

    def set_rate
      @rate = @shipping_method.shipping_rates.find(params[:id])
    end

    def assign_attributes(rate)
      attributes = rate_params.to_h
      price = attributes.delete("price_euros")
      rate.assign_attributes(attributes)
      rate.price_cents = euro_cents(price, attribute: "Le prix")
    end

    def rate_params
      params.require(:shipping_rate).permit(:min_weight_grams, :max_weight_grams, :active, :price_euros)
    end
  end
end

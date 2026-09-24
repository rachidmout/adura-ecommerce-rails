module Admin
  class OrdersController < BaseController
    SHIPPING_CARRIER_OPTIONS = [
      "Colissimo / La Poste",
      "Chronopost",
      "Mondial Relay",
      "DHL",
      "UPS",
      "FedEx"
    ].freeze

    before_action :set_order, only: %i[show prepare ship create_shipment retry_shipment]

    def index
      @orders = Order.includes(:order_items, :payments).order(created_at: :desc)
      @orders = @orders.where(status: params[:status]) if params[:status].present? && Order.statuses.key?(params[:status])
    end

    def show
    end

    def ship
      @order.mark_shipped!(admin_user: current_admin_user, **shipping_details)
      redirect_to admin_order_path(@order), notice: "Commande marquée comme expédiée."
    rescue ActiveRecord::RecordInvalid => error
      message = error.record.errors.full_messages.to_sentence.presence || "Cette commande ne peut pas être expédiée."
      redirect_to admin_order_path(@order), alert: message
    rescue ActionController::ParameterMissing
      redirect_to admin_order_path(@order), alert: "Renseignez le transporteur et le numéro de suivi."
    end

    def prepare
      @order.mark_preparing!(admin_user: current_admin_user)
      redirect_to admin_order_path(@order), notice: "Commande marquée en préparation."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_order_path(@order), alert: "Seule une commande payée peut être mise en préparation."
    end

    def create_shipment
      shipment = Shipping::CreateShipment.new(order: @order).call
      redirect_to admin_order_path(@order), notice: shipment.label_available? ? "Expédition créée : l’étiquette est disponible." : "Expédition créée."
    rescue Shipping::CreateShipment::Error => error
      redirect_to admin_order_path(@order), alert: error.message
    end

    def retry_shipment
      shipment = Shipping::CreateShipment.new(order: @order).call
      redirect_to admin_order_path(@order), notice: shipment.label_available? ? "Expédition recréée : l’étiquette est disponible." : "Expédition recréée."
    rescue Shipping::CreateShipment::Error => error
      redirect_to admin_order_path(@order), alert: error.message
    end

    private

    def set_order
      @order = Order.includes(
        :relay_point, shipment: { label_attachment: :blob },
        order_items: { product_variant: [ :product_images, { product: :product_images } ] },
        payments: :payment_events,
        order_status_events: :admin_user
      ).find(params[:id])
    end

    def shipping_details
      if params.dig(:shipment, :use_created_shipment) == "1"
        shipment = @order.shipment
        raise ActionController::ParameterMissing, :shipment unless shipment&.ready?

        return { shipping_carrier: shipment.carrier, tracking_number: shipment.tracking_number }
      end

      details = params.require(:shipment).permit(:carrier_choice, :shipping_carrier_other, :tracking_number)
      {
        shipping_carrier: details[:carrier_choice] == "other" ? details[:shipping_carrier_other] : details[:carrier_choice],
        tracking_number: details[:tracking_number]
      }
    end
  end
end

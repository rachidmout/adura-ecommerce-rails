class OrdersController < ApplicationController
  before_action :set_order

  def show
    @payment = @order.payments.order(created_at: :desc).first
  end

  def resume
    payment = Payments::CreateCheckoutSession.new(
      order: @order,
      success_url: order_confirmation_url(@order.public_token),
      cancel_url: order_confirmation_url(@order.public_token, cancelled: 1)
    ).call
    redirect_to payment.checkout_url, allow_other_host: true
  rescue Payments::CreateCheckoutSession::ConfigurationError, Payments::CreateCheckoutSession::OrderChanged
    redirect_to order_confirmation_path(@order.public_token), alert: t("orders.show.resume_unavailable")
  end

  private

  def set_order
    @order = Order.includes(:order_items, :payments).find_by!(public_token: params[:public_token])
  end
end

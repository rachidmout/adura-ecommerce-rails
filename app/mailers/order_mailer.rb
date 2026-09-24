class OrderMailer < ApplicationMailer
  def confirmation
    @order = order_from_params

    mail(to: @order.email, subject: "Confirmation de votre commande ADURA")
  end

  def shipped
    @order = order_from_params

    mail(to: @order.email, subject: "Votre commande ADURA est expédiée")
  end

  private

  def order_from_params
    order = params[:order]
    raise ArgumentError, "Une commande valide est requise." unless order.is_a?(Order)

    order
  end
end

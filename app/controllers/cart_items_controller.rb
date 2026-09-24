class CartItemsController < ApplicationController
  def create
    current_cart.add(params.require(:variant_id), params.fetch(:quantity, 1))
    redirect_to cart_path, notice: t("carts.messages.added")
  rescue Cart::Error => error
    redirect_back fallback_location: products_path, alert: error.message
  end

  def update
    current_cart.update(params[:id], params.require(:quantity))
    redirect_to cart_path, notice: t("carts.messages.updated")
  rescue Cart::Error => error
    redirect_to cart_path, alert: error.message
  end

  def destroy
    current_cart.remove(params[:id])
    redirect_to cart_path, notice: t("carts.messages.removed")
  end
end

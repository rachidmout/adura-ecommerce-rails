class ReviewsController < ApplicationController
  before_action :set_product

  # Anti-abus sans service externe : limite native Rails sur cette action
  # (le honeypot ci-dessous filtre les robots simples, ceci filtre les
  # tentatives répétées).
  rate_limit to: 5, within: 1.minute, only: :create, with: -> { redirect_to product_path(@product), alert: I18n.t("products.show.reviews_rate_limited") }

  def create
    if honeypot_filled?
      redirect_to product_path(@product)
      return
    end

    review = @product.reviews.new(review_params)
    if review.save
      redirect_to product_path(@product), notice: t("products.show.reviews_success")
    else
      redirect_to product_path(@product), alert: review.errors.full_messages.to_sentence
    end
  end

  private

  def set_product
    @product = Product.visible.find_by!(slug: params[:product_slug])
  end

  def review_params
    params.require(:review).permit(:author_name, :author_email, :rating, :comment)
  end

  # Champ "nickname" jamais rempli par un humain (caché en CSS, pas en
  # type="hidden" que certains robots savent ignorer) : un formulaire
  # rempli automatiquement le remplit en général aussi.
  def honeypot_filled?
    params.dig(:review, :nickname).present?
  end
end

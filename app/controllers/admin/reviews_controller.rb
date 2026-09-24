module Admin
  class ReviewsController < BaseController
    before_action :set_review, only: %i[approve hide destroy]

    def index
      @reviews = Review.includes(:product).order(created_at: :desc)
      @reviews = @reviews.where(product_id: params[:product_id]) if params[:product_id].present?
      @reviews = @reviews.where(rating: params[:rating]) if params[:rating].present?
      @reviews = @reviews.where(status: params[:status]) if params[:status].present? && Review.statuses.key?(params[:status])
      @products = Product.order(:name)
    end

    def approve
      @review.update!(status: :approved)
      redirect_to admin_reviews_path, notice: "Avis approuvé."
    end

    def hide
      @review.update!(status: :hidden)
      redirect_to admin_reviews_path, notice: "Avis masqué."
    end

    def destroy
      @review.destroy!
      redirect_to admin_reviews_path, notice: "Avis supprimé."
    end

    private

    def set_review
      @review = Review.find(params[:id])
    end
  end
end

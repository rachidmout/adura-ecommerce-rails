module Admin
  class SeoController < BaseController
    def index
      @products = Product.includes(:brand, :product_images).order(:name)
      @incomplete_count = @products.count { |product| !product.seo_complete? }
    end
  end
end

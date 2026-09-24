module Admin
  class CatalogVariantsController < BaseController
    def index
      @variants = ProductVariant.joins(product: :brand).includes(product: :brand).order("brands.name", "products.name", :position, :id)
      @variants = filter_by_query(@variants)
      @variants = @variants.where(products: { brand_id: params[:brand] }) if params[:brand].present?
      @variants = @variants.where(active: params[:status] == "active") if %w[active inactive].include?(params[:status])
      @variants = @variants.low_stock if params[:low_stock] == "1"
      @variants = @variants.where(shipping_weight_grams: nil) if params[:missing_weight] == "1"
      @brands = Brand.active.order(:name)
    end

    def update
      variant = ProductVariant.find(params[:id])
      Admin::UpdateCatalogVariant.new(variant: variant, attributes: catalog_variant_params.to_h.symbolize_keys).call
      redirect_to admin_catalog_variants_path(filter_params), notice: "Variante enregistrée."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_catalog_variants_path(filter_params), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def filter_by_query(variants)
      return variants if params[:q].blank?

      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
      variants.where("products.name ILIKE :query OR product_variants.sku ILIKE :query", query: query)
    end

    def catalog_variant_params
      params.require(:product_variant).permit(:price_euros, :stock_quantity, :active, :shipping_weight_grams)
    end

    def filter_params
      params.permit(:q, :brand, :status, :low_stock, :missing_weight)
    end
  end
end

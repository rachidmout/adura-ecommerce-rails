module Admin
  class VariantsController < BaseController
    before_action :set_product
    before_action :set_variant, only: %i[edit update destroy duplicate]

    def index
      @variants = @product.product_variants
    end

    def new
      @variant = @product.product_variants.new(currency: "EUR", stock_quantity: 0, reserved_stock_quantity: 0, active: true)
    end

    def create
      @variant = @product.product_variants.new(variant_params)
      generate_sku_if_blank(@variant)
      if @variant.save
        redirect_to edit_admin_product_path(@product), notice: "Variante créée."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if update_variant
        redirect_to edit_admin_product_path(@product), notice: "Variante enregistrée."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @variant.historical?
        @variant.update!(active: false)
        redirect_to edit_admin_product_path(@product), notice: "Variante désactivée : son historique de commande ou de réservation doit être conservé."
      else
        @variant.destroy!
        redirect_to edit_admin_product_path(@product), notice: "Variante supprimée."
      end
    end

    def duplicate
      duplicated = ProductVariant.transaction do
        source = @product.product_variants.lock.find(@variant.id)
        @product.product_variants.create!(
          sku: ProductVariant.next_sku(product_slug: @product.slug, volume_ml: source.volume_ml),
          volume_ml: source.volume_ml,
          price_cents: source.price_cents,
          currency: source.currency,
          stock_quantity: 0,
          reserved_stock_quantity: 0,
          active: source.active?,
          position: source.position,
          shipping_weight_grams: source.shipping_weight_grams
        )
      end
      redirect_to edit_admin_product_variant_path(@product, duplicated), notice: "Variante dupliquée : vérifiez son SKU avant publication."
    end

    private

    def set_product
      @product = Product.find_by!(slug: params[:product_id])
    end

    def set_variant
      @variant = @product.product_variants.find(params[:id])
    end

    def variant_params
      params.require(:product_variant).permit(:sku, :gtin, :volume_ml, :price_euros, :currency, :stock_quantity, :active, :position, :shipping_weight_grams)
    end

    def generate_sku_if_blank(variant)
      return unless variant.sku.blank? && variant.volume_ml.present?

      variant.sku = ProductVariant.next_sku(product_slug: @product.slug, volume_ml: variant.volume_ml)
    end

    def update_variant
      ProductVariant.transaction do
        @variant.lock!
        @variant.assign_attributes(variant_params)
        @variant.save
      end
    end
  end
end

module Admin
  class PromoCodesController < BaseController
    before_action :set_promo_code, only: %i[edit update]

    def index
      @promo_codes = PromoCode.order(created_at: :desc)
    end

    def new
      @promo_code = PromoCode.new(discount_type: "percentage", active: true)
    end

    def create
      @promo_code = PromoCode.new(promo_code_params)
      if @promo_code.save
        assign_scopes
        redirect_to admin_promo_codes_path, notice: "Code promo créé."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @promo_code.update(promo_code_params)
        assign_scopes
        redirect_to admin_promo_codes_path, notice: "Code promo enregistré."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_promo_code
      @promo_code = PromoCode.find(params[:id])
    end

    def promo_code_params
      params.require(:promo_code).permit(
        :code, :discount_type, :discount_value, :starts_at, :ends_at, :active,
        :max_uses, :max_uses_per_customer, :min_order_cents
      )
    end

    # Ciblage optionnel produits/familles, même style que assign_notes côté
    # produits : on reconstruit la liste à partir de ce qui est coché.
    def assign_scopes
      product_ids = Array(params[:promo_code][:product_ids]).reject(&:blank?)
      @promo_code.promo_code_products.where.not(product_id: product_ids).destroy_all
      product_ids.each { |id| @promo_code.promo_code_products.find_or_create_by!(product_id: id) }

      family_ids = Array(params[:promo_code][:olfactory_family_ids]).reject(&:blank?)
      @promo_code.promo_code_olfactory_families.where.not(olfactory_family_id: family_ids).destroy_all
      family_ids.each { |id| @promo_code.promo_code_olfactory_families.find_or_create_by!(olfactory_family_id: id) }
    end
  end
end

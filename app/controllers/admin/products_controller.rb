module Admin
  class ProductsController < BaseController
    before_action :set_product, only: %i[show edit update destroy publish archive duplicate]

    def index
      @products = Product.includes(:brand, :perfume_profile, product_variants: [], product_olfactory_families: :olfactory_family)
                          .search(params[:q])
                          .order(created_at: :desc)
      @products = @products.where(brand_id: params[:brand]) if params[:brand].present?
      @products = @products.where(status: params[:status]) if params[:status].present? && Product.statuses.key?(params[:status])
      @products = @products.where(id: PerfumeProfile.where(audience: params[:audience]).select(:product_id)) if params[:audience].present?
      @products = @products.where(id: ProductOlfactoryFamily.primary.where(olfactory_family_id: params[:family]).select(:product_id)) if params[:family].present?
      @products = @products.in_stock if params[:availability] == "in_stock"
      @products = @products.out_of_stock if params[:availability] == "out_of_stock"
      @products = @products.where(id: ProductVariant.active.low_stock.select(:product_id)) if params[:low_stock] == "1"

      @brands = Brand.active.order(:name)
      @families = OlfactoryFamily.active
    end

    # Aucun contenu propre : la fiche "produit" utilisable au quotidien est
    # la page d'édition (informations + variantes + galerie + publication
    # réunies). On y redirige plutôt que de maintenir deux pages qui
    # afficheraient la même chose.
    def show
      redirect_to edit_admin_product_path(@product)
    end

    def new
      @product = Product.new
      @product.build_perfume_profile
    end

    def create
      @product = Product.new(product_params)
      if @product.save
        assign_sources_and_family
        assign_notes
        redirect_to edit_admin_product_path(@product), notice: "Produit créé en brouillon."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @product.build_perfume_profile unless @product.perfume_profile
    end

    def update
      if @product.update(product_params)
        assign_sources_and_family
        assign_notes
        redirect_to edit_admin_product_path(@product), notice: "Produit enregistré."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @product.archive!
      redirect_to admin_products_path, notice: "Produit archivé."
    end

    def publish
      @product.publish!
      redirect_to edit_admin_product_path(@product), notice: "Produit publié."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to edit_admin_product_path(@product), alert: error.record.errors.full_messages.to_sentence
    end

    def archive
      @product.archive!
      redirect_to edit_admin_product_path(@product), notice: "Produit archivé."
    end

    def duplicate
      duplicated_product = Admin::DuplicateProduct.new(product: @product).call
      redirect_to edit_admin_product_path(duplicated_product), notice: "Produit dupliqué en brouillon."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to edit_admin_product_path(@product), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def set_product
      @product = Product.includes(
        :brand, :perfume_profile, :product_images,
        product_variants: [],
        product_olfactory_families: :olfactory_family,
        product_olfactory_notes: :olfactory_note
      ).find_by!(slug: params[:id])
    end

    def product_params
      params.require(:product).permit(
        :brand_id, :name, :slug, :short_description, :description, :featured, :verified_at,
        :meta_title, :meta_description,
        perfume_profile_attributes: [ :id, :audience, :concentration, :intensity_level, :longevity_level, :sillage_level ]
      )
    end

    def assign_sources_and_family
      source_urls = params[:product][:source_urls_text].to_s.lines.map(&:strip).reject(&:blank?)
      @product.update_column(:source_urls, source_urls)

      family_id = params[:product][:primary_family_id].presence
      return unless family_id

      @product.product_olfactory_families.where(role: :primary).where.not(olfactory_family_id: family_id).destroy_all
      association = @product.product_olfactory_families.find_or_initialize_by(olfactory_family_id: family_id)
      association.update!(role: :primary)
    end

    # Une note peut apparaître dans une seule couche à la fois (contrainte
    # d'unicité product_id+olfactory_note_id+layer) : on reconstruit la
    # liste de chaque couche à partir des cases cochées dans le formulaire,
    # même principe que assign_sources_and_family ci-dessus. La position
    # suit l'ordre de soumission (ordre alphabétique de la liste), il n'y a
    # pas de tri manuel au sein d'une couche.
    def assign_notes
      %i[top heart base].each do |layer|
        note_ids = Array(params.dig(:product, :"#{layer}_note_ids")).reject(&:blank?)
        @product.product_olfactory_notes.where(layer: layer).where.not(olfactory_note_id: note_ids).destroy_all
        note_ids.each_with_index do |note_id, index|
          @product.product_olfactory_notes.find_or_initialize_by(layer: layer, olfactory_note_id: note_id).update!(position: index)
        end
      end
    end
  end
end

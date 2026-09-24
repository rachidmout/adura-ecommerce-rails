class ProductsController < ApplicationController
  # Segments d'URL français (/parfums/genre/femme) vers la valeur interne
  # stockée en base (PerfumeProfile#audience) — l'ancien filtre en query
  # string (?audience=women) continue de fonctionner, les deux passent par
  # la même résolution ci-dessous.
  AUDIENCE_SEGMENTS = { "femme" => "women", "homme" => "men", "mixte" => "unisex" }.freeze

  def index
    @families = OlfactoryFamily.active
    @brands = Brand.active.order(:name)
    @models = Product.visible.order(:name)
    @current_family = current_family
    @current_audience = resolve_audience
    @current_brand = @brands.find { |brand| brand.id.to_s == params[:brand].to_s }
    @current_model = @models.find { |model| model.slug == params[:model] }
    @analytics_catalog_search_event = helpers.analytics_catalog_search_event(
      query: params[:q],
      family: @current_family,
      brand: @current_brand,
      model: @current_model,
      audience: @current_audience,
      max_price: params[:max_price]
    )
    @products = filtered_products.includes(:brand, :perfume_profile, :product_variants, product_images: { file_attachment: :blob }).order(:name).distinct
  end

  def show
    @product = Product.visible.includes(
      :brand,
      :perfume_profile,
      { product_variants: { product_images: { file_attachment: :blob } } },
      product_images: { file_attachment: :blob },
      product_olfactory_families: :olfactory_family,
      product_olfactory_notes: :olfactory_note
    ).find_by(slug: params[:slug])

    return redirect_to_current_slug_or_404 unless @product

    @variants = @product.product_variants
    @reviews = @product.reviews.approved.recent
    @related_products = Product.visible
      .joins(:product_olfactory_families)
      .where(product_olfactory_families: { olfactory_family_id: @product.primary_family&.id })
      .where.not(id: @product.id)
      .includes(:brand, :product_variants, product_images: { file_attachment: :blob })
      .distinct.limit(3)
  end

  private

  # Un produit renommé (changement de slug) laisse une trace dans
  # product_redirects (voir Product#record_slug_redirect) : on redirige de
  # façon permanente vers l'URL actuelle plutôt que de renvoyer une 404 sur
  # un lien qui était valide hier.
  def redirect_to_current_slug_or_404
    redirect = ProductRedirect.find_by(old_slug: params[:slug])
    current_product = redirect&.product
    if current_product && Product.visible.exists?(id: current_product.id)
      redirect_to product_path(current_product), status: :moved_permanently
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def resolve_audience
    return AUDIENCE_SEGMENTS[params[:audience]] if AUDIENCE_SEGMENTS.key?(params[:audience])
    return params[:audience] if params[:audience].in?(AUDIENCE_SEGMENTS.values)

    nil
  end

  # Une URL SEO de famille inconnue ne doit jamais retomber silencieusement
  # sur le catalogue général : cela créerait une soft-404 et un canonical
  # trompeur. Les filtres historiques par query string restent permissifs.
  def current_family
    return OlfactoryFamily.active.find_by(slug: params[:family]) if params[:slug].blank?

    OlfactoryFamily.active.find_by!(slug: params[:slug])
  end

  def filtered_products
    scope = Product.visible.search(params[:q])
    scope = scope.where(brand_id: params[:brand]) if params[:brand].present?
    scope = scope.where(slug: params[:model]) if params[:model].present?
    scope = scope.joins(:product_olfactory_families).where(product_olfactory_families: { olfactory_family_id: @current_family.id }) if @current_family
    scope = scope.joins(:perfume_profile).where(perfume_profiles: { audience: @current_audience }) if @current_audience
    if params[:max_price].present?
      scope = scope.joins(:product_variants).where(product_variants: { active: true, price_cents: ..params[:max_price].to_i })
    end
    scope
  end
end

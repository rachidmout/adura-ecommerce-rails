module Ai
  # Source publique, volontairement limitée aux informations déjà visibles
  # dans le catalogue. Elle sert aux outils marketing sans exposer les données
  # d'administration, de commandes ou de stock détaillé.
  # Exemple de forme : { "catalogue_version": "v1", "products": [{ "slug": "yara", "formats": [] }] }
  class CataloguesController < ApplicationController
    def show
      products = public_products

      if stale?(etag: [ "ai-catalogue-v1", catalogue_last_modified ], last_modified: catalogue_last_modified, public: true)
        render json: {
          catalogue_version: "v1",
          products: products.map { |product| serialize_product(product) }
        }
      end
    end

    private

    def public_products
      Product.visible
        .joins(:product_variants)
        .merge(ProductVariant.active)
        .includes(
          :brand,
          :perfume_profile,
          { product_variants: [] },
          { product_images: { file_attachment: :blob } },
          { product_olfactory_families: :olfactory_family },
          { product_olfactory_notes: :olfactory_note }
        )
        .distinct
        .order(:name)
    end

    def catalogue_last_modified
      @catalogue_last_modified ||= [
        Product.visible.maximum(:updated_at),
        ProductVariant.joins(:product).merge(Product.visible).active.maximum(:updated_at),
        ProductImage.joins(:product).merge(Product.visible).maximum(:updated_at),
        PerfumeProfile.joins(:product).merge(Product.visible).maximum(:updated_at),
        ProductOlfactoryFamily.joins(:product).merge(Product.visible).maximum(:updated_at),
        ProductOlfactoryNote.joins(:product).merge(Product.visible).maximum(:updated_at)
      ].compact.max
    end

    def serialize_product(product)
      variants = product.product_variants.select(&:active?)
      images = product.product_images.select { |image| image.file.attached? }
      primary_image = images.find(&:primary?) || images.first
      profile = product.perfume_profile

      {
        name: product.name,
        slug: product.slug,
        brand: product.brand.name,
        url: product_url(product, locale: nil),
        formats: variants.map { |variant| serialize_variant(variant) },
        minimum_price: money_data(variants.map(&:price_cents).min),
        olfactory_family: serialize_family(product),
        audience: profile&.audience,
        short_description: product.short_description,
        description: product.description,
        meta_title: product.meta_title,
        meta_description: product.meta_description,
        olfactory_notes: serialize_notes(product),
        availability: variants.any? { |variant| variant.available_stock_quantity.positive? } ? "in_stock" : "out_of_stock",
        primary_image_url: image_url(primary_image),
        secondary_image_urls: images.reject { |image| image == primary_image }.map { |image| image_url(image) },
        marketing_tags: marketing_tags(profile)
      }.compact
    end

    def serialize_variant(variant)
      {
        format: variant.label,
        volume_ml: variant.volume_ml,
        price: money_data(variant.price_cents),
        availability: variant.available_stock_quantity.positive? ? "in_stock" : "out_of_stock"
      }
    end

    def serialize_family(product)
      relation = product.product_olfactory_families.find(&:primary?)
      family = relation&.olfactory_family
      return if family.nil?

      { name: family.name, slug: family.slug }
    end

    def serialize_notes(product)
      %w[top heart base].to_h do |layer|
        notes = product.product_olfactory_notes
          .select { |note| note.layer == layer }
          .sort_by(&:position)
          .map { |note| note.olfactory_note.name }
        [ layer, notes ]
      end
    end

    def marketing_tags(profile)
      return {} if profile.nil?

      {
        concentration: profile.concentration,
        intensity: profile.intensity_level,
        longevity: profile.longevity_level,
        sillage: profile.sillage_level,
        styles: profile.style_codes.presence,
        occasions: profile.occasion_codes.presence,
        seasons: profile.season_codes.presence
      }.compact
    end

    def money_data(cents)
      { amount: cents / 100.0, currency: "EUR" }
    end

    def image_url(image)
      return if image.nil? || !image.file.attached?

      rails_blob_url(image.file, host: request.base_url)
    end
  end
end

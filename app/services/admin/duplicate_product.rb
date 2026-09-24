module Admin
  class DuplicateProduct
    def initialize(product:)
      @product = product
    end

    def call
      Product.transaction do
        source = Product.lock.find(@product.id)
        duplicated = create_product!(source)
        copy_perfume_profile!(source, duplicated)
        copy_families!(source, duplicated)
        copy_notes!(source, duplicated)
        variants_by_source_id = copy_variants!(source, duplicated)
        copy_images!(source, duplicated, variants_by_source_id)
        duplicated
      end
    end

    private

    def create_product!(source)
      slug = next_slug(source.slug)
      Product.create!(
        brand: source.brand,
        name: "#{source.name} Copie",
        slug: slug,
        short_description: source.short_description,
        description: source.description,
        source_urls: source.source_urls,
        verified_at: source.verified_at,
        meta_title: source.meta_title,
        meta_description: source.meta_description,
        status: :draft,
        published_at: nil,
        archived_at: nil,
        featured: false,
        featured_position: nil
      )
    end

    def copy_perfume_profile!(source, duplicated)
      return unless source.perfume_profile

      duplicated.create_perfume_profile!(source.perfume_profile.attributes.slice(
        "audience", "concentration", "intensity_level", "longevity_level", "sillage_level", "season_codes", "occasion_codes", "style_codes"
      ))
    end

    def copy_families!(source, duplicated)
      source.product_olfactory_families.find_each do |association|
        duplicated.product_olfactory_families.create!(olfactory_family: association.olfactory_family, role: association.role)
      end
    end

    def copy_notes!(source, duplicated)
      source.product_olfactory_notes.find_each do |note|
        duplicated.product_olfactory_notes.create!(
          olfactory_note: note.olfactory_note,
          layer: note.layer,
          position: note.position
        )
      end
    end

    def copy_variants!(source, duplicated)
      source.product_variants.order(:position, :id).each_with_object({}) do |variant, variants_by_source_id|
        copied_variant = duplicated.product_variants.create!(
          sku: ProductVariant.next_sku(product_slug: duplicated.slug, volume_ml: variant.volume_ml),
          volume_ml: variant.volume_ml,
          price_cents: variant.price_cents,
          currency: variant.currency,
          stock_quantity: 0,
          reserved_stock_quantity: 0,
          active: variant.active?,
          position: variant.position,
          shipping_weight_grams: variant.shipping_weight_grams
        )
        variants_by_source_id[variant.id] = copied_variant
      end
    end

    def copy_images!(source, duplicated, variants_by_source_id)
      source.product_images.order(:position, :id).each do |image|
        copied_image = duplicated.product_images.create!(
          # Preserve the admin-authored value. ProductImage#alt_text only
          # localizes generic text at render time and must not freeze that
          # generated translation into the duplicated record.
          alt_text: image[:alt_text],
          position: image.position,
          primary: image.primary?,
          product_variant: image.product_variant_id && variants_by_source_id.fetch(image.product_variant_id)
        )
        copied_image.file.attach(image.file.blob) if image.file.attached?
      end
    end

    def next_slug(source_slug)
      base_slug = "#{source_slug}-copie"
      suffix = 1
      candidate = base_slug

      while Product.exists?(slug: candidate)
        suffix += 1
        candidate = "#{base_slug}-#{suffix}"
      end

      candidate
    end
  end
end

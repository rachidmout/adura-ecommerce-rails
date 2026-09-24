require "test_helper"

module Admin
  class DuplicateProductTest < ActiveSupport::TestCase
    test "duplicates editorial data, catalog data and shared image blobs into a draft" do
      source = build_source_product
      source.reviews.create!(author_name: "Client", author_email: "client@example.com", rating: 5, comment: "Excellent parfum")
      source_variant = source.product_variants.first
      source_variant.update!(shipping_weight_grams: 340)
      order = create_paid_order(variant: source_variant)
      order.payments.create!(provider: "stripe", status: :succeeded, amount_cents: order.total_cents, currency: "EUR")
      source_image = source.product_images.order(:position).last

      duplicated = nil
      assert_no_difference [ "ActiveStorage::Blob.count", "Order.count", "OrderItem.count", "Payment.count", "Review.count" ] do
        duplicated = DuplicateProduct.new(product: source).call
      end

      assert duplicated.draft?
      assert_equal "#{source.name} Copie", duplicated.name
      assert_equal "#{source.slug}-copie", duplicated.slug
      assert_equal source.brand, duplicated.brand
      assert_equal source.description, duplicated.description
      assert_equal source.short_description, duplicated.short_description
      assert_equal source.source_urls, duplicated.source_urls
      assert_equal source.meta_title, duplicated.meta_title
      assert_equal source.meta_description, duplicated.meta_description
      assert_not duplicated.featured?
      assert_nil duplicated.published_at

      assert_equal source.perfume_profile.attributes.slice("audience", "concentration", "intensity_level", "longevity_level", "sillage_level", "season_codes", "occasion_codes", "style_codes"),
                   duplicated.perfume_profile.attributes.slice("audience", "concentration", "intensity_level", "longevity_level", "sillage_level", "season_codes", "occasion_codes", "style_codes")
      assert_equal source.product_olfactory_families.order(:olfactory_family_id).pluck(:olfactory_family_id, :role), duplicated.product_olfactory_families.order(:olfactory_family_id).pluck(:olfactory_family_id, :role)
      assert_equal source.product_olfactory_notes.order(:layer, :position).pluck(:olfactory_note_id, :layer, :position), duplicated.product_olfactory_notes.order(:layer, :position).pluck(:olfactory_note_id, :layer, :position)

      assert_equal source.product_variants.count, duplicated.product_variants.count
      duplicated.product_variants.each do |variant|
        source_variant = source.product_variants.find_by!(volume_ml: variant.volume_ml)
        assert_equal source_variant.price_cents, variant.price_cents
        assert_equal source_variant.shipping_weight_grams, variant.shipping_weight_grams
        assert_equal source_variant.active?, variant.active?
        assert_equal 0, variant.stock_quantity
        assert_equal 0, variant.reserved_stock_quantity
        assert_match(/\AADURA-#{Regexp.escape(duplicated.slug.upcase)}-#{variant.volume_ml}(?:-\d+)?\z/, variant.sku)
      end

      assert_equal source.product_images.order(:position).pluck(:position, :primary, :alt_text), duplicated.product_images.order(:position).pluck(:position, :primary, :alt_text)
      assert_equal source.product_images.order(:position).map { |image| image.file.blob_id }, duplicated.product_images.order(:position).map { |image| image.file.blob_id }
      assert_equal source.product_images.order(:position).map { |image| image.product_variant&.volume_ml }, duplicated.product_images.order(:position).map { |image| image.product_variant&.volume_ml }

      assert_empty duplicated.reviews
      assert_equal [ order.id ], Order.where(id: order.id).pluck(:id)
      assert_equal 1, OrderItem.where(order: order).count
      assert_equal 1, Payment.where(order: order).count

      duplicated_image = duplicated.product_images.find_by!(position: source_image.position)
      duplicated_image.file.purge
      assert source_image.reload.file.attached?
      assert ActiveStorage::Blob.exists?(source_image.file.blob_id)
    end

    test "adds a suffix for repeated product and SKU collisions" do
      source = build_source_product

      first_copy = DuplicateProduct.new(product: source).call
      second_copy = DuplicateProduct.new(product: source).call

      assert_equal "#{source.slug}-copie", first_copy.slug
      assert_equal "#{source.slug}-copie-2", second_copy.slug
      assert_equal "ADURA-#{second_copy.slug.upcase}-100", second_copy.product_variants.find_by!(volume_ml: 100).sku
      assert_equal second_copy.product_variants.count, second_copy.product_variants.pluck(:sku).uniq.count
    end

    test "rolls back the full duplication if an image copy fails" do
      source = build_source_product
      service = DuplicateProduct.new(product: source)
      service.define_singleton_method(:copy_images!) { |_source, _duplicated, _variants| raise "image copy failure" }

      assert_no_difference [ "Product.count", "ProductVariant.count", "ProductImage.count" ] do
        assert_raises(RuntimeError, "image copy failure") { service.call }
      end
    end

    private

    def build_source_product
      source = create_publishable_product(slug: "duplicate-source", price_cents: 2400, stock_quantity: 7)
      source.update!(short_description: "Description courte à copier", description: "Description complète à copier", source_urls: [ "https://example.com/source" ], meta_title: "Titre SEO", meta_description: "Description SEO", featured: true)
      source.perfume_profile.update!(concentration: "eau_de_parfum", intensity_level: "intense", longevity_level: "long", sillage_level: "strong", season_codes: [ "autumn" ], occasion_codes: [ "evening" ], style_codes: [ "gourmand" ])
      secondary_family = OlfactoryFamily.find_or_create_by!(slug: "duplicate-secondary") { |family| family.name = "Secondaire" }
      source.product_olfactory_families.create!(olfactory_family: secondary_family, role: :secondary)
      top_note = OlfactoryNote.create!(name: "Mandarine", slug: "duplicate-top-note")
      heart_note = OlfactoryNote.create!(name: "Jasmin", slug: "duplicate-heart-note")
      source.product_olfactory_notes.create!(olfactory_note: top_note, layer: :top, position: 0)
      source.product_olfactory_notes.create!(olfactory_note: heart_note, layer: :heart, position: 0)
      second_variant = source.product_variants.create!(sku: "ADURA-DUPLICATE-SOURCE-50", volume_ml: 50, price_cents: 1800, stock_quantity: 3, active: false, currency: "EUR", position: 1)
      second_variant.update!(shipping_weight_grams: 180)
      image = source.product_images.create!(alt_text: "Image du format 50 ml", product_variant: second_variant, position: 1)
      image.file.attach(io: File.open(file_fixture("bottle.jpg")), filename: "bottle.jpg", content_type: "image/jpeg")
      source
    end
  end
end

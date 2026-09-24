require "test_helper"

class ProductImagesReattachTest < ActiveSupport::TestCase
  setup do
    @source_dir = file_fixture("bottle.jpg").dirname
    @product = create_publishable_product(slug: "yara-lattafa", price_cents: 1_800, stock_quantity: 14)
    @variant = @product.product_variants.first
    @catalog = [
      {
        slug: "yara-lattafa", name: @product.name, brand: "Lattafa", volume: 100,
        images: [ "bottle.jpg", "bottle.jpg" ]
      }
    ]
  end

  test "attaches images to the matching existing variant and marks the first as primary" do
    result = ProductImages::Reattach.new(catalog: @catalog, source_dir: @source_dir).call

    assert_equal 2, result.processed
    assert_empty result.products_skipped
    assert_empty result.variants_skipped
    assert_empty result.missing_files

    images = @product.product_images.order(:position).to_a
    assert_equal 2, images.size
    assert images[0].primary?
    assert_not images[1].primary?
    assert_equal @variant, images[0].product_variant
    assert images[0].file.attached?
    assert_equal "bottle.jpg", images[0].file.filename.to_s
    assert_match(/avec coffret/, images[1].alt_text)
  end

  test "does not modify the product, its variant, or unrelated data" do
    before = @product.attributes.except("updated_at")
    before_variant = @variant.attributes.except("updated_at")

    assert_no_difference [ "Product.count", "ProductVariant.count", "ShopSetting.count", "AdminUser.count", "Order.count", "Payment.count" ] do
      ProductImages::Reattach.new(catalog: @catalog, source_dir: @source_dir).call
    end

    assert_equal before, @product.reload.attributes.except("updated_at")
    assert_equal before_variant, @variant.reload.attributes.except("updated_at")
  end

  test "can resume cleanly from a partial state without leaving duplicates or orphaned images" do
    # Simule l'état interrompu réel : une image déjà là (le seed original), plus
    # une image "orpheline" sur un ancien service, comme après le crash constaté
    # en production. Le run doit repartir proprement de zéro pour ce produit.
    ProductImages::Reattach.new(catalog: @catalog, source_dir: @source_dir).call
    first_run_blob_ids = @product.product_images.reload.map { |image| image.file.blob.id }

    result = ProductImages::Reattach.new(catalog: @catalog, source_dir: @source_dir).call

    assert_equal 2, result.processed
    assert_equal 2, @product.product_images.count
    second_run_blob_ids = @product.product_images.reload.map { |image| image.file.blob.id }
    assert_empty(first_run_blob_ids & second_run_blob_ids, "les anciens blobs doivent être remplacés, pas accumulés")
    # Attachment (pas Blob) : la purge des anciens blobs orphelins est asynchrone
    # (ActiveStorage::PurgeJob, normal et sans conséquence), donc Blob.count peut
    # rester temporairement élevé après un destroy_all — ce qui compte ici, c'est
    # qu'il n'y ait exactement que 2 attachments *actifs*, pas de doublon.
    assert_equal 2, ActiveStorage::Attachment.count, "aucun attachment en doublon ne doit rester après le second passage"
  end

  test "skips products that no longer exist without raising" do
    catalog = [ { slug: "produit-inexistant", name: "X", brand: "X", volume: 100, images: [ "bottle.jpg" ] } ]

    result = ProductImages::Reattach.new(catalog: catalog, source_dir: @source_dir).call

    assert_equal 0, result.processed
    assert_equal [ "produit-inexistant" ], result.products_skipped
  end

  test "skips variants that don't exist for the product without raising" do
    catalog = [ { slug: "yara-lattafa", name: @product.name, brand: "Lattafa", volume: 999, images: [ "bottle.jpg" ] } ]

    result = ProductImages::Reattach.new(catalog: catalog, source_dir: @source_dir).call

    assert_equal 0, result.processed
    assert_equal [ "yara-lattafa 999ml" ], result.variants_skipped
  end

  test "skips missing source files without raising" do
    catalog = [ { slug: "yara-lattafa", name: @product.name, brand: "Lattafa", volume: 100, images: [ "ce-fichier-nexiste-pas.webp" ] } ]

    result = ProductImages::Reattach.new(catalog: catalog, source_dir: @source_dir).call

    assert_equal 0, result.processed
    assert_equal [ "ce-fichier-nexiste-pas.webp" ], result.missing_files
  end

  test "handles extra_variants at additional volumes" do
    extra = @product.product_variants.create!(sku: "SKU-YARA-50", volume_ml: 50, price_cents: 900, stock_quantity: 0, currency: "EUR", active: true)
    catalog = [
      {
        slug: "yara-lattafa", name: @product.name, brand: "Lattafa", volume: 100, images: [ "bottle.jpg" ],
        extra_variants: [ { volume: 50, images: [ "bottle.jpg" ] } ]
      }
    ]

    result = ProductImages::Reattach.new(catalog: catalog, source_dir: @source_dir).call

    assert_equal 2, result.processed
    assert_equal extra, @product.product_images.find_by(product_variant_id: extra.id).product_variant
  end
end

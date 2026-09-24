require "test_helper"

class Ai::CataloguesControllerTest < ActionDispatch::IntegrationTest
  test "exposes a stable public marketing catalogue without internal data" do
    product = create_publishable_product(slug: "ai-catalogue-visible", price_cents: 2_500)
    product.update!(short_description: "Une description courte", description: "Une description marketing complète.",
                    meta_title: "Titre SEO", meta_description: "Description SEO")
    product.product_variants.create!(sku: "SKU-AI-INACTIVE", volume_ml: 50, price_cents: 1_500,
                                     stock_quantity: 4, reserved_stock_quantity: 0, currency: "EUR", active: false)
    product.product_images.create!(alt_text: "Vue secondaire", primary: false).tap do |image|
      image.file.attach(io: File.open(file_fixture("bottle.jpg")), filename: "bottle-secondary.jpg", content_type: "image/jpeg")
    end
    top_note = OlfactoryNote.create!(name: "Bergamote AI", slug: "bergamote-ai")
    ProductOlfactoryNote.create!(product: product, olfactory_note: top_note, layer: :top, position: 0)

    hidden_product = create_publishable_product(slug: "ai-catalogue-hidden")
    hidden_product.update!(status: :draft, published_at: nil)

    get "/ai/catalogue.json"

    assert_response :success
    assert_equal "application/json", response.media_type
    payload = response.parsed_body
    catalogue_product = payload.fetch("products").find { |entry| entry.fetch("slug") == product.slug }

    assert_equal "v1", payload.fetch("catalogue_version")
    assert_nil payload.fetch("products").find { |entry| entry.fetch("slug") == hidden_product.slug }
    assert_equal product.name, catalogue_product.fetch("name")
    assert_equal product.brand.name, catalogue_product.fetch("brand")
    assert_equal product_url(product, locale: nil), catalogue_product.fetch("url")
    assert_equal({ "name" => product.primary_family.name, "slug" => product.primary_family.slug }, catalogue_product.fetch("olfactory_family"))
    assert_equal [ "Bergamote AI" ], catalogue_product.fetch("olfactory_notes").fetch("top")
    assert_equal "in_stock", catalogue_product.fetch("availability")
    assert_equal({ "amount" => 25.0, "currency" => "EUR" }, catalogue_product.fetch("minimum_price"))
    assert_equal 1, catalogue_product.fetch("formats").size
    assert_equal "100 ml", catalogue_product.fetch("formats").first.fetch("format")
    assert_equal({ "amount" => 25.0, "currency" => "EUR" }, catalogue_product.fetch("formats").first.fetch("price"))
    assert_equal "in_stock", catalogue_product.fetch("formats").first.fetch("availability")
    assert_match %r{/rails/active_storage/blobs/redirect/}, catalogue_product.fetch("primary_image_url")
    assert_equal 1, catalogue_product.fetch("secondary_image_urls").size
    assert_equal [ "daily" ], catalogue_product.fetch("marketing_tags").fetch("occasions")

    %w[id sku stock_quantity reserved_stock_quantity shipping_weight_grams source_urls verified_at].each do |private_key|
      refute_includes response.body, "\"#{private_key}\""
    end
  end

  test "supports conditional public caching" do
    create_publishable_product(slug: "ai-catalogue-cache")

    get "/ai/catalogue.json"
    etag = response.headers.fetch("ETag")

    get "/ai/catalogue.json", headers: { "If-None-Match" => etag }

    assert_response :not_modified
  end
end

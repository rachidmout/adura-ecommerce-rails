require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  # product_url(product) est ambigu ici : la route a deux segments
  # dynamiques ("(/:locale)/parfums/:slug") et, sans
  # ApplicationController#default_url_options pour préremplir la langue
  # (actif en conditions réelles, pas dans ce contexte de test), le premier
  # argument positionnel se lie au mauvais segment. On passe le slug
  # explicitement pour lever toute ambiguïté.
  def product_url_for(product)
    product_url(slug: product.slug, locale: nil)
  end

  test "product page title falls back to a generated one when no custom meta_title is set" do
    product = create_publishable_product(slug: "seo-fallback-title-test")
    variant = product.product_variants.find(&:active?)
    expected_title = [ product.name, product.brand.name, variant.label, product.primary_family.name ].join(" ") + " | ADURA"

    get product_url_for(product)

    assert_select "title", expected_title
  end

  test "a custom meta_title overrides the generated one" do
    product = create_publishable_product(slug: "seo-custom-title-test")
    product.update!(meta_title: "Titre sur mesure pour Google")

    get product_url_for(product)

    assert_select "title", "Titre sur mesure pour Google"
  end

  test "product page renders a canonical link pointing to its own URL" do
    product = create_publishable_product(slug: "seo-canonical-test")

    get product_url_for(product)

    assert_select "link[rel=canonical][href=?]", product_url_for(product)
  end

  test "product page includes Product JSON-LD structured data" do
    product = create_publishable_product(slug: "seo-jsonld-test")

    get product_url_for(product)

    product_data = structured_data(response.body).find { |data| data["@type"] == "Product" }
    offer = product_data.fetch("offers").first

    assert_equal product.name, product_data.fetch("name")
    assert_equal product_url_for(product), product_data.fetch("url")
    assert_equal product.product_variants.first.sku, product_data.fetch("sku")
    price_specification = offer.fetch("priceSpecification")
    reference_quantity = price_specification.fetch("referenceQuantity")

    assert_equal "UnitPriceSpecification", price_specification.fetch("@type")
    assert_equal "EUR", price_specification.fetch("priceCurrency")
    assert_equal "20.00", price_specification.fetch("price")
    assert_equal 100, reference_quantity.fetch("value")
    assert_equal "ML", reference_quantity.fetch("unitCode")
    assert_equal 100, reference_quantity.fetch("valueReference").fetch("value")
    assert_equal "ML", reference_quantity.fetch("valueReference").fetch("unitCode")
    assert_equal "https://schema.org/NewCondition", offer.fetch("itemCondition")
    assert_equal "https://schema.org/InStock", offer.fetch("availability")
    assert_not offer.key?("shippingDetails")
    assert_not product_data.key?("gtin")
  end

  test "unit price structured data uses the real 60 ml variant volume" do
    product = create_publishable_product(slug: "ana-abiyedh")
    product.product_variants.first.update!(volume_ml: 60)

    get product_url_for(product)

    offer = structured_data(response.body).find { |data| data["@type"] == "Product" }.fetch("offers").first
    reference_quantity = offer.fetch("priceSpecification").fetch("referenceQuantity")

    assert_equal 60, reference_quantity.fetch("value")
    assert_equal "ML", reference_quantity.fetch("unitCode")
    assert_equal 100, reference_quantity.fetch("valueReference").fetch("value")
    assert_equal "ML", reference_quantity.fetch("valueReference").fetch("unitCode")
  end

  test "a product with multiple active formats uses ProductGroup without inventing GTINs" do
    product = create_publishable_product(slug: "seo-product-group-test")
    product.product_variants.create!(
      sku: "SKU-SEO-PRODUCT-GROUP-50",
      volume_ml: 50,
      price_cents: 1_500,
      stock_quantity: 0,
      currency: "EUR",
      active: true
    )
    product.product_variants.create!(
      sku: "SKU-SEO-PRODUCT-GROUP-10",
      volume_ml: 10,
      price_cents: 900,
      stock_quantity: 2,
      currency: "EUR",
      active: true
    )

    get product_url_for(product)

    group = structured_data(response.body).find { |data| data["@type"] == "ProductGroup" }
    variants = group.fetch("hasVariant")

    assert_equal "ADURA-#{product.id}", group.fetch("productGroupID")
    assert_equal [ "https://schema.org/size" ], group.fetch("variesBy")
    assert_equal [ "100 ml", "50 ml", "10 ml" ], variants.map { |variant| variant.fetch("size") }
    assert_equal [ product.product_variants.first.sku, "SKU-SEO-PRODUCT-GROUP-50", "SKU-SEO-PRODUCT-GROUP-10" ], variants.map { |variant| variant.fetch("sku") }
    assert_equal "https://schema.org/InStock", variants.first.fetch("offers").fetch("availability")
    assert_equal "https://schema.org/OutOfStock", variants.second.fetch("offers").fetch("availability")
    assert_equal [ 100, 50, 10 ], variants.map { |variant| variant.fetch("offers").fetch("priceSpecification").fetch("referenceQuantity").fetch("value") }
    assert variants.all? { |variant| variant.fetch("offers").fetch("priceSpecification").fetch("referenceQuantity").fetch("valueReference").slice("value", "unitCode") == { "value" => 100, "unitCode" => "ML" } }
    assert variants.none? { |variant| variant.keys.any? { |key| key.start_with?("gtin") } }
  end

  test "AggregateRating is only present once the product has an approved review" do
    product = create_publishable_product(slug: "seo-no-rating-test")
    get product_url_for(product)
    assert_no_match(/AggregateRating/, response.body)

    product.reviews.create!(author_name: "Client", author_email: "client@example.com", rating: 5, comment: "Très bien", status: :approved)
    get product_url_for(product)
    assert_match(/"@type":"AggregateRating"/, response.body)
  end

  test "a renamed product's old URL redirects permanently to the new one" do
    product = create_publishable_product(slug: "seo-redirect-old-slug")
    old_url = product_url_for(product)
    product.update!(slug: "seo-redirect-new-slug")

    get old_url

    assert_redirected_to product_url_for(product)
    assert_response :moved_permanently
  end

  test "an unknown slug with no redirect returns 404" do
    get product_url(slug: "this-slug-has-never-existed", locale: nil)

    assert_response :not_found
  end

  test "family and audience clean URLs filter the catalog and set a canonical URL" do
    product = create_publishable_product(slug: "seo-family-catalog-test", family_slug: "gourmand")

    get family_catalog_url(slug: "gourmand", locale: nil)

    assert_response :success
    assert_select "title", I18n.t("seo.families.gourmand.title")
    assert_select "meta[name='description'][content=?]", I18n.t("seo.families.gourmand.meta_description")
    assert_select "h1", I18n.t("seo.families.gourmand.heading")
    assert_select "link[rel=canonical][href=?]", family_catalog_url(slug: "gourmand", locale: nil)
    assert_select ".product-card", text: /#{Regexp.escape(product.name)}/
  end

  test "catalog hub metadata is localized and keeps its canonical and hreflang links" do
    I18n.available_locales.each do |locale|
      get products_url(locale: locale)

      assert_response :success
      assert_select "title", I18n.t("seo.catalog.title", locale: locale)
      assert_select "meta[name='description'][content=?]", I18n.t("seo.catalog.meta_description", locale: locale)
      assert_select "h1", I18n.t("seo.catalog.heading", locale: locale)
      assert_select "link[rel=canonical][href=?]", products_url(locale: locale)
      assert_select "link[rel=alternate][hreflang='en']"
      assert_select "link[rel=alternate][hreflang='nl'][href=?]", products_url(locale: :nl)
    end
  end

  test "canonical catalog hubs render editorial SEO copy in every locale" do
    create_publishable_product(slug: "canonical-hub-seo-copy", family_slug: "gourmand")

    I18n.available_locales.each do |locale|
      get products_path(locale: locale)

      assert_response :success
      assert_select ".seo-hub-copy[aria-label=?]", I18n.t("seo.hub_copy_aria", locale: locale)
      assert_select ".seo-hub-copy", text: I18n.t("seo.catalog.body", locale: locale)

      get audience_catalog_path(audience: "femme", locale: locale)

      assert_response :success
      assert_select ".seo-hub-copy", text: I18n.t("seo.audiences.women.body", locale: locale)

      get family_catalog_path(slug: "gourmand", locale: locale)

      assert_response :success
      assert_select ".seo-hub-copy", text: I18n.t("seo.families.gourmand.body", locale: locale)
    end
  end

  test "catalog hubs do not render long SEO copy when a query string filter is present" do
    create_publishable_product(slug: "filtered-hub-seo-copy", family_slug: "gourmand")

    I18n.available_locales.each do |locale|
      paths = [
        products_path(locale: locale),
        audience_catalog_path(audience: "femme", locale: locale),
        family_catalog_path(slug: "gourmand", locale: locale)
      ]

      %w[q family brand model audience max_price].each do |filter|
        paths.each do |path|
          get path, params: { filter => "test" }

          assert_response :success
          assert_select ".seo-hub-copy", count: 0
        end
      end
    end
  end

  test "product context links use the current locale" do
    product = create_publishable_product(slug: "localized-product-context", family_slug: "gourmand")

    %i[en es de it nl].each do |locale|
      get product_url(slug: product.slug, locale: locale)

      assert_response :success
      assert_select ".product-context-links[aria-label=?]", I18n.t("products.show.context_links_aria", locale: locale)
      assert_select ".product-context-links a", text: I18n.t("products.show.context_brand", locale: locale, brand: product.brand.name)
      assert_select ".product-context-links a", text: I18n.t("products.show.context_gourmand", locale: locale)
      assert_select ".product-context-links a", text: I18n.t("products.show.context_catalog", locale: locale)
      assert_select "link[rel=canonical][href=?]", product_url(slug: product.slug, locale: locale)
      assert_select "link[rel=alternate][hreflang='nl'][href=?]", product_url(slug: product.slug, locale: :nl)
    end
  end

  test "localized product copy uses the verified olfactory pyramid instead of a generic family fallback" do
    product = create_publishable_product(slug: "localized-product-copy", family_slug: "gourmand")
    notes = {
      top: [ "Bergamote", "Cannelle" ],
      heart: [ "Jasmin" ],
      base: [ "Vanille" ]
    }
    notes.each do |layer, names|
      names.each_with_index do |name, position|
        note = OlfactoryNote.find_or_create_by!(slug: name.parameterize) { |record| record.name = name }
        ProductOlfactoryNote.create!(product: product, olfactory_note: note, layer: layer, position: position)
      end
    end

    %i[en es de it nl].each do |locale|
      get product_url(slug: product.slug, locale: locale)

      top_notes = [
        I18n.t("olfactory_notes.bergamote.name", locale: locale),
        I18n.t("olfactory_notes.cannelle.name", locale: locale)
      ].join(" #{I18n.t('products.generated.notes_connector', locale: locale)} ")
      expected_short = I18n.t(
        "products.generated.short_description_with_notes",
        locale: locale,
        name: product.name,
        brand: product.brand.name,
        family: I18n.t("olfactory_families.gourmand.name", locale: locale).downcase,
        top_notes: top_notes,
        base_notes: I18n.t("olfactory_notes.vanille.name", locale: locale)
      )
      expected_description = I18n.t(
        "products.generated.description_with_notes",
        locale: locale,
        name: product.name,
        brand: product.brand.name,
        family: I18n.t("olfactory_families.gourmand.name", locale: locale).downcase,
        top_notes: top_notes,
        heart_notes: I18n.t("olfactory_notes.jasmin.name", locale: locale),
        base_notes: I18n.t("olfactory_notes.vanille.name", locale: locale)
      )

      assert_response :success
      assert_select "meta[name='description'][content=?]", expected_short
      assert_select ".product-detail-description", text: expected_description
      assert_no_match(/classified in the|clasificada en la|klassifiziert|classificata nella|referentie uit de geurfamilie/, response.body)
    end
  end

  test "audience hub has dedicated metadata and introductory content" do
    get audience_catalog_url(audience: "femme", locale: nil)

    assert_response :success
    assert_select "title", I18n.t("seo.audiences.women.title")
    assert_select "meta[name='description'][content=?]", I18n.t("seo.audiences.women.meta_description")
    assert_select "h1", I18n.t("seo.audiences.women.heading")
    assert_select "link[rel=canonical][href=?]", audience_catalog_url(audience: "femme", locale: nil)
  end

  test "an unknown family clean URL returns 404 instead of the generic catalog" do
    get family_catalog_url(slug: "famille-inconnue", locale: nil)

    assert_response :not_found
  end

  test "legacy products catalog URL redirects permanently to the canonical catalog" do
    get "/products"

    assert_response :moved_permanently
    assert_redirected_to products_url(locale: nil)
  end

  test "canonical catalog URL responds successfully with its canonical URL" do
    get products_path(locale: nil)

    assert_response :success
    assert_select "link[rel=canonical][href=?]", products_url(locale: nil)
  end

  test "catalog exposes an accessible mobile filters control and one product link per card" do
    product = create_publishable_product(slug: "mobile-catalog-card-test")

    get products_path

    assert_response :success
    assert_select "button.catalog-filter-toggle[aria-controls='catalog-filter-form'][aria-expanded='false']"
    assert_select "form#catalog-filter-form[data-controller='auto-submit']"
    assert_select ".product-card a.product-card-link[href=?]", product_path(product), count: 1
    assert_select ".product-card a.product-card-link h3", text: product.name, count: 1
    assert_select ".product-card img[loading='lazy'][sizes='(max-width: 640px) 46vw, (max-width: 980px) 44vw, 360px'][srcset*='320w'][srcset*='480w'][srcset*='720w']"
  end

  test "catalog shows a compact active filters summary with a reset link" do
    matching = create_publishable_product(slug: "mobile-filter-matching")
    other = create_publishable_product(slug: "mobile-filter-other")

    get products_path, params: { q: matching.name }

    assert_response :success
    assert_select ".catalog-active-filters", text: /1 filtre actif/
    assert_select ".catalog-active-filters a.filter-reset[href=?]", products_path, text: "Effacer"
    assert_select ".product-card", text: /#{Regexp.escape(matching.name)}/
    assert_select ".product-card", text: /#{Regexp.escape(other.name)}/, count: 0
  end

  test "catalog search analytics keeps free text private and uses only controlled filters" do
    product = create_publishable_product(slug: "analytics-catalog-search", family_slug: "gourmand")
    private_search = "client@example.com recherche personnelle"

    get products_path, params: {
      q: private_search,
      family: product.primary_family.slug,
      brand: product.brand.id,
      model: product.slug,
      audience: "unisex",
      max_price: "2000"
    }

    assert_response :success
    element = Nokogiri::HTML(response.body).at_css(".catalog[data-catalog-analytics-search-value]")
    payload_json = element["data-catalog-analytics-search-value"]
    payload = JSON.parse(payload_json)

    assert_equal true, payload.fetch("search_used")
    assert_equal product.primary_family.slug, payload.fetch("filter_family")
    assert_equal product.brand.slug, payload.fetch("filter_brand")
    assert_equal product.slug, payload.fetch("filter_model")
    assert_equal "unisex", payload.fetch("filter_audience")
    assert_equal "2000", payload.fetch("filter_max_price")
    assert_equal 6, payload.fetch("filters_count")
    assert_no_match(/#{Regexp.escape(private_search)}/, payload_json)
    assert_no_match(/email|phone|address|postal|city/i, payload_json)
  end

  test "catalog does not render a search analytics payload without a search or valid filters" do
    get products_path

    assert_response :success
    assert_select ".catalog[data-catalog-analytics-search-value]", count: 0
  end

  test "product page renders a sticky mobile CTA inside the existing cart form" do
    product = create_publishable_product(slug: "sticky-product-cta")
    first_variant = product.product_variants.first
    second_variant = product.product_variants.create!(sku: "SKU-STICKY-PRODUCT-CTA-50", volume_ml: 50, price_cents: 1_500, stock_quantity: 3, currency: "EUR", active: true)

    get product_url_for(product)

    assert_response :success
    assert_select "form.purchase-box[action=?]", cart_items_path(locale: nil), count: 1
    assert_select "form.purchase-box input[name='variant_id'][value='#{first_variant.id}']"
    assert_select "button.variant-option[data-variant-id='#{second_variant.id}'][data-variant-label='50 ml'][data-price='15,00 €'][data-analytics-hook='variant-option']"
    assert_select ".product-sticky-cta[data-analytics-hook='product-sticky-cta']"
    assert_select ".product-sticky-cta [data-variant-target='stickyPrice']", text: "20,00 €"
    assert_select ".product-sticky-cta input[type='submit'][data-variant-target='submit'][data-analytics-hook='product-add-to-cart']"
    assert_select ".product-detail-visual img[data-variant-target='gallery'][loading='eager'][fetchpriority='high'][srcset*='480w'][srcset*='1200w']"
    assert_select ".product-gallery-thumb img[loading='lazy'][sizes='56px'][srcset*='120w']"
  end

  test "product page renders every gallery image in a scrollable track with accessible thumbnails" do
    product = create_publishable_product(slug: "scrollable-product-gallery")
    variant = product.product_variants.first
    product.primary_image.update!(product_variant: variant)
    second_image = product.product_images.create!(product_variant: variant, alt_text: "Deuxième flacon de test", primary: false, position: 1)
    second_image.file.attach(io: File.open(file_fixture("bottle.jpg")), filename: "second-bottle.jpg", content_type: "image/jpeg")

    get product_url_for(product)

    assert_response :success
    assert_select ".product-gallery-track[data-variant-target='galleryTrack'][data-action='scroll->variant#syncGallery']"
    assert_select ".product-gallery-slide[data-variant-target='gallerySlide']", count: 2
    assert_select ".product-gallery-slide img[data-variant-target='gallery'][alt='Flacon de test'][loading='eager'][fetchpriority='high']", count: 1
    assert_select ".product-gallery-slide img[data-variant-target='gallery'][alt='Deuxième flacon de test'][loading='lazy']", count: 1
    assert_select ".product-gallery-thumb[data-action='variant#showImage'][aria-pressed='true']", count: 1
    assert_select ".product-gallery-thumb[data-action='variant#showImage'][aria-label='Voir l’image 2']", count: 1
  end

  test "product page marks unavailable variants and the initial sticky CTA as disabled" do
    product = create_publishable_product(slug: "sticky-unavailable-product", stock_quantity: 0)

    get product_url_for(product)

    assert_response :success
    assert_select "button.variant-option[disabled][data-available='false'][aria-pressed='true']"
    assert_select ".product-sticky-cta input[type='submit'][disabled][value='Indisponible']"
  end

  test "product page exposes a server-built ecommerce payload without customer data" do
    product = create_publishable_product(slug: "analytics-product")
    variant = product.product_variants.first

    get product_url_for(product)

    element = Nokogiri::HTML(response.body).at_css(".product-detail[data-ecommerce-analytics-view-item-value]")
    payload_json = element["data-ecommerce-analytics-view-item-value"]
    payload = JSON.parse(payload_json)

    assert_equal "EUR", payload.fetch("currency")
    assert_equal variant.price_cents / 100.0, payload.fetch("value")
    assert_equal variant.sku, payload.fetch("items").first.fetch("item_id")
    assert_equal product.name, payload.fetch("items").first.fetch("item_name")
    assert_select "form.purchase-box[data-action='submit->ecommerce-analytics#addToCart']"
    assert_select "button.variant-option[data-action='variant#select ecommerce-analytics#selectVariant'][data-ecommerce-analytics-item]"
    assert_no_match(/email|phone|address|postal|city/i, payload_json)
  end

  test "cart creation continues to use the variant identifier submitted by the product form" do
    product = create_publishable_product(slug: "sticky-cart-variant")
    selected_variant = product.product_variants.create!(sku: "SKU-STICKY-CART-VARIANT-50", volume_ml: 50, price_cents: 1_500, stock_quantity: 3, currency: "EUR", active: true)

    post cart_items_path(locale: nil), params: { variant_id: selected_variant.id, quantity: 1 }

    assert_redirected_to cart_path(locale: nil)
    follow_redirect!
    assert_select ".cart-item", text: /#{Regexp.escape(selected_variant.label)}/
  end

  private

  def structured_data(body)
    Nokogiri::HTML(body).css("script[type='application/ld+json']").map { |script| JSON.parse(script.text) }
  end
end

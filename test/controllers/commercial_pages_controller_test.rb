require "test_helper"

class CommercialPagesControllerTest < ActionDispatch::IntegrationTest
  test "gourmand page renders only relevant available products with SEO metadata" do
    gourmand = create_publishable_product(slug: "page-gourmand", family_slug: "gourmand")
    fruity = create_publishable_product(slug: "page-fruity", family_slug: "fruite")

    get gourmand_perfumes_url(locale: nil)

    assert_response :success
    assert_select "title", I18n.t("commercial_pages.gourmands.title")
    assert_select "meta[name='description'][content=?]", I18n.t("commercial_pages.gourmands.meta_description")
    assert_select "link[rel=canonical][href=?]", gourmand_perfumes_url(locale: nil)
    assert_select "link[rel=alternate][hreflang='en']"
    assert_select ".product-card", text: /#{Regexp.escape(gourmand.name)}/
    assert_select ".product-card", text: /#{Regexp.escape(fruity.name)}/, count: 0
    assert_match(/"@type":"CollectionPage"/, response.body)
    assert_match(/"@type":"BreadcrumbList"/, response.body)
  end

  test "Lattafa and Dubai pages render their configured products" do
    lattafa = create_publishable_product(slug: "page-lattafa")
    dubai = create_publishable_product(slug: "page-dubai")
    lattafa.update!(brand: Brand.find_or_create_by!(slug: "lattafa") { |brand| brand.name = "Lattafa" })
    dubai.update!(brand: Brand.find_or_create_by!(slug: "paris-corner") { |brand| brand.name = "Paris Corner" })

    get lattafa_perfumes_url(locale: nil)
    assert_response :success
    assert_select ".product-card", text: /#{Regexp.escape(lattafa.name)}/

    get dubai_perfumes_url(locale: nil)
    assert_response :success
    assert_select ".product-card", text: /#{Regexp.escape(dubai.name)}/
  end

  test "commercial pages are localized through their existing public routes" do
    create_publishable_product(slug: "page-gourmand-localized", family_slug: "gourmand")

    %i[en nl].each do |locale|
      get gourmand_perfumes_url(locale: locale)

      assert_response :success
      assert_select "html[lang=?]", locale
      assert_select "h1", I18n.t("commercial_pages.gourmands.heading", locale: locale)
      assert_select "nav.breadcrumb[aria-label=?]", I18n.t("commercial_pages.breadcrumb", locale: locale)
      assert_select "link[rel=canonical][href=?]", gourmand_perfumes_url(locale: locale)
    end
  end

  test "commercial page returns 404 when its configured selection is empty" do
    get gourmand_perfumes_url(locale: nil)

    assert_response :not_found
  end
end

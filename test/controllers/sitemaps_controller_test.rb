require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "lists published products and static pages but never admin, cart or checkout URLs" do
    product = create_publishable_product(slug: "sitemap-visible-test")
    draft = create_publishable_product(slug: "sitemap-draft-test")
    draft.update_column(:status, "draft")

    get sitemap_url(format: :xml, locale: nil)

    assert_response :success
    assert_match %r{<loc>[^<]*/parfums</loc>}, response.body
    assert_match %r{<loc>[^<]*/parfums-gourmands</loc>}, response.body
    assert_match %r{<loc>[^<]*/parfums-lattafa</loc>}, response.body
    assert_match %r{<loc>[^<]*/parfums-dubai</loc>}, response.body
    assert_match "/parfums/sitemap-visible-test", response.body
    assert_no_match "/parfums/sitemap-draft-test", response.body
    assert_no_match %r{<loc>[^<]*/products</loc>}, response.body
    assert_no_match "/admin", response.body
    assert_no_match "/panier", response.body
    assert_no_match "/commande", response.body
  end

  test "each URL entry lists hreflang alternates for every locale" do
    get sitemap_url(format: :xml, locale: nil)

    assert_response :success
    assert_match 'hreflang="fr"', response.body
    assert_match 'hreflang="en"', response.body
    assert_match 'hreflang="nl"', response.body
    assert_match %r{href="[^"]*/nl/parfums"}, response.body
    assert_match 'hreflang="x-default"', response.body
  end
end

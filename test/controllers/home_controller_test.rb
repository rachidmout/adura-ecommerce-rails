require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "home page is accessible" do
    get root_url
    assert_response :success
    assert_select "h1", /Votre prochain parfum/
    assert_select "title", I18n.t("home.index.meta_title")
    assert_select "meta[name='description'][content=?]", I18n.t("home.index.meta_description")
  end

  test "header exposes an accessible mobile navigation trigger and cart" do
    get root_url

    assert_response :success
    assert_select "body[data-controller='cookie-consent']"
    assert_select "header.site-header[data-controller='menu']"
    assert_select "button.menu-button[type='button'][data-menu-target='button'][data-action='click->menu#toggle'][aria-controls='navigation-principale'][aria-expanded='false']"
    assert_select "nav#navigation-principale[data-menu-target='navigation'][data-action='click->menu#close']"
    assert_select ".mobile-menu-backdrop[data-menu-target='backdrop'][data-action='click->menu#close'][hidden]"
    assert_select "a.cart-link[aria-label]"
    assert_select "button.language-trigger[aria-haspopup='listbox'][aria-expanded='false']"
  end

  test "main navigation has a localized accessible label" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      assert_response :success
      assert_select "nav#navigation-principale[aria-label=?]", I18n.t("layout.main_navigation", locale: locale)
    end
  end

  test "language selector exposes Nederlands and its localized URL" do
    get root_url

    assert_response :success
    assert_select ".language-option[href='/nl/']", text: /Nederlands/
  end

  test "footer exposes secure Instagram and TikTok links in every locale" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      assert_response :success
      assert_select "a.footer-social-link[href='https://www.instagram.com/adura.shop/'][target='_blank'][rel='noopener noreferrer'][aria-label=?]", I18n.t("layout.footer.instagram", locale: locale)
      assert_select "a.footer-social-link[href='https://www.tiktok.com/@adura.store'][target='_blank'][rel='noopener noreferrer'][aria-label=?]", I18n.t("layout.footer.tiktok", locale: locale)
    end
  end

  test "organization schema lists both official social profiles" do
    get root_url

    assert_response :success
    assert_match "https://www.instagram.com/adura.shop/", response.body
    assert_match "https://www.tiktok.com/@adura.store", response.body
  end

  test "organization schema exposes the documented return policy for active delivery countries" do
    zone = ShippingZone.create!(name: "France", active: true)
    zone.shipping_zone_countries.create!(country_code: "FR")

    get root_url

    organization = structured_data(response.body).find { |data| data["@type"] == "OnlineStore" }
    policy = organization.fetch("hasMerchantReturnPolicy")

    assert_equal [ "FR" ], policy.fetch("applicableCountry")
    assert_equal "FR", policy.fetch("returnPolicyCountry")
    assert_equal returns_url, policy.fetch("merchantReturnLink")
    assert_equal "https://schema.org/MerchantReturnFiniteReturnWindow", policy.fetch("returnPolicyCategory")
    assert_equal 14, policy.fetch("merchantReturnDays")
    assert_equal "https://schema.org/ReturnByMail", policy.fetch("returnMethod")
    assert_equal "https://schema.org/ReturnFeesCustomerResponsibility", policy.fetch("returnFees")
  end

  test "hero prioritizes only its central product image" do
    create_publishable_product(slug: "yara-lattafa")
    create_publishable_product(slug: "kenzie-marshmallow-dream")
    create_publishable_product(slug: "vanilla-latte")

    get root_url

    assert_response :success
    assert_select ".hero-product-marshmallow img[loading='eager'][fetchpriority='high'][width='410'][height='760']"
    assert_select ".hero-product-yara img[fetchpriority]", count: 0
    assert_select ".hero-product-vanilla img[fetchpriority]", count: 0
  end

  test "family links use their clean SEO slugs" do
    product = create_publishable_product(slug: "home-family-link", family_slug: "gourmand")

    get root_url

    assert_response :success
    assert_select ".family-links a[href=?]", family_catalog_path(slug: product.primary_family.slug), count: 1
    assert_select ".family-links a[href*='family=']", count: 0
  end

  private

  def structured_data(body)
    Nokogiri::HTML(body).css("script[type='application/ld+json']").map { |script| JSON.parse(script.text) }
  end
end

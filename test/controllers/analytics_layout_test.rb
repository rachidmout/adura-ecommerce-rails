require "test_helper"

class AnalyticsLayoutTest < ActionDispatch::IntegrationTest
  def setup
    @previous_measurement_id = ENV["GA4_MEASUREMENT_ID"]
  end

  def teardown
    ENV["GA4_MEASUREMENT_ID"] = @previous_measurement_id
  end

  test "public pages do not expose GA4 configuration when it is absent" do
    ENV.delete("GA4_MEASUREMENT_ID")

    get root_url

    assert_response :success
    assert_select "meta[name='ga4-measurement-id']", count: 0
    assert_select "script[src*='googletagmanager.com']", count: 0
    assert_select "section.cookie-consent[role='dialog'][data-cookie-consent-target='banner'][hidden]"
    assert_select "button[type='button'][data-action='cookie-consent#accept']", text: "Accepter"
    assert_select "button[type='button'][data-action='cookie-consent#reject']", text: "Refuser"
    assert_select "button[type='button'][data-action='cookie-consent#openPreferences'][data-cookie-consent-target='preferencesTrigger']", text: "Personnaliser"
    assert_select "form[data-cookie-consent-target='preferences'][data-action*='cookie-consent#save']"
    assert_select "input[data-cookie-consent-target='analytics'][checked]", count: 0
  end

  test "public pages expose only the configured GA4 measurement ID" do
    ENV["GA4_MEASUREMENT_ID"] = "G-ADURA123"

    get root_url

    assert_response :success
    assert_select "meta[name='ga4-measurement-id'][content='G-ADURA123']"
    assert_select "script[src*='googletagmanager.com']", count: 0
    assert_select "button[data-action='cookie-consent#openPreferences'][data-cookie-consent-target='preferencesTrigger']", minimum: 2
  end

  test "cookie consent copy is available in every public locale" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      assert_response :success
      assert_select ".cookie-consent h2", text: I18n.t("cookie_consent.title", locale: locale)
      assert_select ".footer-preferences-link", text: I18n.t("layout.footer.cookie_preferences", locale: locale)
    end
  end

  test "admin layout never exposes GA4 configuration or cookie consent UI" do
    ENV["GA4_MEASUREMENT_ID"] = "G-ADURA123"
    admin_user = create_admin_user
    sign_in_as(admin_user)

    get admin_root_path

    assert_response :success
    assert_select "meta[name='ga4-measurement-id']", count: 0
    assert_select ".cookie-consent", count: 0
  end

  test "analytics module initializes Google tag before configuring its manual page view" do
    source = Rails.root.join("app/javascript/analytics.js").read

    initialization_index = source.index('window.gtag("js", new Date())')
    configuration_index = source.index('window.gtag("config", measurementId, { send_page_view: false })')
    page_view_index = source.index('window.gtag("event", "page_view", pendingPageView)')

    assert_not_nil initialization_index
    assert_not_nil configuration_index
    assert_not_nil page_view_index
    assert_operator initialization_index, :<, configuration_index
    assert_operator configuration_index, :<, page_view_index
  end

  test "content security policy authorizes GA4 script and collection endpoints" do
    source = Rails.root.join("config/initializers/content_security_policy.rb").read

    assert_includes source, "https://www.googletagmanager.com"
    assert_includes source, "https://www.google-analytics.com"
    assert_includes source, "https://region1.google-analytics.com"
  end

  test "ecommerce events remain blocked without explicit analytics consent" do
    source = Rails.root.join("app/javascript/analytics.js").read
    controller_source = Rails.root.join("app/javascript/controllers/ecommerce_analytics_controller.js").read
    quiz_controller_source = Rails.root.join("app/javascript/controllers/quiz_analytics_controller.js").read
    catalog_controller_source = Rails.root.join("app/javascript/controllers/catalog_analytics_controller.js").read

    assert_includes source, "if (!measurementId || analyticsConsent() !== true) return false"
    assert_includes controller_source, "adura_purchase_tracked_${transactionId}"
    assert_includes controller_source, "track(\"purchase\", this.purchaseValue, `purchase:${transactionId}`)"
    assert_includes quiz_controller_source, "trackAnalyticsEvent"
    assert_includes quiz_controller_source, "BUDGET_RANGES"
    assert_includes catalog_controller_source, "trackAnalyticsEvent"
    assert_includes catalog_controller_source, "aucune requête de recherche libre"
  end
end

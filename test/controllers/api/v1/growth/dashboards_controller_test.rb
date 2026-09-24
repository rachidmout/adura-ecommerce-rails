require "test_helper"

class Api::V1::Growth::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "returns the default seven day aggregated dashboard with a valid token" do
    create_paid_order

    with_growth_token do |token|
      get api_v1_growth_dashboard_path, headers: authorization_header(token)
    end

    assert_response :success
    payload = response.parsed_body
    assert_equal %w[business funnel ga4 insights landing_pages meta products traffic_sources], payload.keys.sort
    assert_equal "7d", payload.dig("meta", "period")
    assert_equal "adura_database", payload.dig("business", "source")
    assert_equal "ga4", payload.dig("ga4", "source")
    assert_equal 1, payload.dig("business", "orders")
    assert_equal [], payload.fetch("products")
    %w[email first_name last_name phone address payment stripe].each { |key| refute_includes response.body, key }
  end

  test "accepts each supported period" do
    with_growth_token do |token|
      %w[today 7d 30d].each do |period|
        get api_v1_growth_dashboard_path(period: period), headers: authorization_header(token)

        assert_response :success
        assert_equal period, response.parsed_body.dig("meta", "period")
      end
    end
  end

  test "refuses missing, malformed and incorrect bearer tokens" do
    with_growth_token do
      get api_v1_growth_dashboard_path
      assert_response :unauthorized
      assert_equal({ "error" => "unauthorized" }, response.parsed_body)

      get api_v1_growth_dashboard_path, headers: { "Authorization" => "Token test-growth-token" }
      assert_response :unauthorized

      get api_v1_growth_dashboard_path, headers: authorization_header("incorrect-token")
      assert_response :unauthorized
    end
  end

  test "rejects an unsupported period without querying dashboard services" do
    with_growth_token do |token|
      get api_v1_growth_dashboard_path(period: "90d"), headers: authorization_header(token)
    end

    assert_response :bad_request
    assert_equal({ "error" => "invalid_period" }, response.parsed_body)
  end

  test "returns a successful JSON response when GA4 uses its stale fallback" do
    with_growth_token do |token|
      with_stale_ga4_dashboard do
        get api_v1_growth_dashboard_path, headers: authorization_header(token)
      end
    end

    assert_response :success
    assert_equal "stale", response.parsed_body.dig("meta", "ga4_status")
    assert_equal true, response.parsed_body.dig("meta", "ga4_fallback")
  end

  test "does not expose a mutation route" do
    with_growth_token do |token|
      post api_v1_growth_dashboard_path, headers: authorization_header(token)
    end

    assert_response :not_found
  end

  private

  def stale_dashboard(period)
    report = Analytics::Ga4Dashboard::Report.new(
      period, :stale, "Dernières données disponibles.", empty_kpis, [], [], [], stale_advanced, empty_comparisons
    )
    Struct.new(:report) { def call = report }.new(report)
  end

  def with_stale_ga4_dashboard
    original_new = Analytics::Ga4Dashboard.method(:new)
    dashboard = stale_dashboard("7d")
    Analytics::Ga4Dashboard.define_singleton_method(:new) { |period:| dashboard }
    yield
  ensure
    Analytics::Ga4Dashboard.define_singleton_method(:new, original_new)
  end

  def stale_advanced
    Analytics::Ga4Dashboard::AdvancedReport.new(:stale, nil, [], [], { started: 0, completed: 0 }, 0, { steps: [], biggest_drop: nil }, [], [], [])
  end

  def empty_kpis
    { active_users: 0, sessions: 0, page_views: 0, product_views: 0, add_to_carts: 0, begin_checkouts: 0, purchases: 0, conversion_rate: 0 }
  end

  def empty_comparisons
    empty_kpis.to_h { |key, value| [ key, Analytics::KpiComparison.build(current: value, previous: nil) ] }
  end

  def with_growth_token
    previous_token = ENV["ADURA_GROWTH_API_TOKEN"]
    ENV["ADURA_GROWTH_API_TOKEN"] = "test-growth-token"
    yield ENV.fetch("ADURA_GROWTH_API_TOKEN")
  ensure
    ENV["ADURA_GROWTH_API_TOKEN"] = previous_token
  end

  def authorization_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end

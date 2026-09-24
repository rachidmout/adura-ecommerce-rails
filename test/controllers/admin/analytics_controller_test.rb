require "test_helper"

module Admin
  class AnalyticsControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_analytics_path

      assert_redirected_to admin_login_path
    end

    test "renders the local business dashboard and its controlled periods for an admin" do
      sign_in_as(create_admin_user)
      paid = create_paid_order
      paid.update_column(:paid_at, Time.current)
      pending = create_paid_order(status: :pending)

      get admin_analytics_path(period: "today")

      assert_response :success
      assert_select "h1", "Analytics"
      assert_select ".sales-chart-period a.is-active", text: "Aujourd’hui"
      assert_select ".admin-card", text: /CA officiel · DB ADURA/
      assert_select ".admin-card", text: /Commandes payées\s*1/
      assert_select ".admin-card", text: /Articles vendus\s*1/
      assert_select ".admin-card", text: /Commandes payées\s*2/, count: 0
      assert_select ".admin-table", text: /#{Regexp.escape(paid.order_items.first.product_name)}/
      assert_no_match(/#{Regexp.escape(paid.email)}|#{Regexp.escape(pending.email)}|#{Regexp.escape(paid.phone)}|#{Regexp.escape(paid.address_line1)}/, response.body)
    end

    test "keeps local metrics available and shows a safe GA4 fallback when it is not configured" do
      sign_in_as(create_admin_user)
      without_ga4_configuration do
        get admin_analytics_path
      end

      assert_response :success
      assert_select ".admin-card", text: /CA officiel · DB ADURA/
      assert_select "[data-ga4-analytics]", text: /Données GA4 non configurées/
      assert_select ".analytics-comparison--not_available", text: /N\/A/
      assert_no_match(/GOOGLE_APPLICATION_CREDENTIALS|private_key|GA4_PROPERTY_ID/, response.body)
    end

    test "renders GA4 metrics returned by the server-side dashboard" do
      sign_in_as(create_admin_user)
      ga4_report = Analytics::Ga4Dashboard::Report.new(
        "today",
        :available,
        nil,
        { active_users: 12, sessions: 20, page_views: 45, product_views: 9, add_to_carts: 4, begin_checkouts: 3, purchases: 2, conversion_rate: 10.0 },
        [ { name: "google / organic", sessions: 10, active_users: 8 } ],
        [ { name: "mobile", sessions: 14, active_users: 9 } ],
        [ { name: "France", sessions: 16, active_users: 11 } ],
        Analytics::Ga4Dashboard::AdvancedReport.new(
          :available,
          nil,
          [ { name: "Yara", item_id: "ADURA-YARA-100", views: 9, add_to_carts: 4, purchases: 2, revenue: 74.0, cart_rate: 44.44, purchase_rate: 22.22 } ],
          [ { name: "Yara", item_id: "ADURA-YARA-100", views: 9, add_to_carts: 4, purchases: 2, revenue: 74.0, cart_rate: 44.44, purchase_rate: 22.22 } ],
          { started: 8, family_selected: 7, budget_selected: 6, completed: 4, completion_rate: 50.0 },
          5,
          funnel,
          [ { name: "Yara", item_id: "ADURA-YARA-100", views: 9, add_to_carts: 4, purchases: 2, revenue: 74.0, cart_rate: 44.44, purchase_rate: 22.22 } ],
          [ { name: "google / organic", sessions: 10, active_users: 8, purchases: 2, revenue: 74.0, conversion_rate: 20.0 } ],
          [ { path: "/parfums/yara", sessions: 10, active_users: 8, engagement_rate: 75.0, purchases: 2, revenue: 74.0, conversion_rate: 20.0 } ]
        ),
        ga4_comparisons
      )
      dashboard = Struct.new(:report) do
        def call
          report
        end
      end.new(ga4_report)

      with_ga4_dashboard(dashboard) do
        get admin_analytics_path(period: "today")
      end

      assert_response :success
      assert_select "[data-ga4-analytics] .admin-card", text: /Utilisateurs actifs\s*12/
      assert_select "[data-ga4-analytics] .admin-card", text: /Conversion GA4\s*10%/
      assert_select "[data-ga4-advanced-analytics]", text: /Funnel GA4/
      assert_select ".admin-funnel-step", text: /Sessions/
      assert_select ".admin-table", text: /Yara.*ADURA-YARA-100.*74/
      assert_select ".admin-table", text: /google \/ organic.*20/
      assert_select ".admin-table", text: /\/parfums\/yara/
      assert_select "h2", "Utilisation du quiz"
      assert_select "h2", "Recherche et filtres"
    end

    test "renders clean empty states when GA4 has no product data for the period" do
      sign_in_as(create_admin_user)
      ga4_report = Analytics::Ga4Dashboard::Report.new(
        "today", :available, nil,
        { active_users: 0, sessions: 0, page_views: 0, product_views: 0, add_to_carts: 0, begin_checkouts: 0, purchases: 0, conversion_rate: 0 },
        [], [], [],
        Analytics::Ga4Dashboard::AdvancedReport.new(
          :available, nil, [], [],
          { started: 0, family_selected: 0, budget_selected: 0, completed: 0, completion_rate: 0 },
          0,
          { steps: [], biggest_drop: nil },
          [],
          [],
          []
        ),
        ga4_comparisons
      )
      dashboard = Struct.new(:report) do
        def call
          report
        end
      end.new(ga4_report)

      with_ga4_dashboard(dashboard) { get admin_analytics_path(period: "today") }

      assert_response :success
      assert_select ".admin-table-empty", text: "Aucune donnée sur cette période.", count: 3
      assert_select "h2", "Recherche et filtres"
    end

    test "falls back to the safe seven day period for an invalid value" do
      sign_in_as(create_admin_user)

      get admin_analytics_path(period: "all-time")

      assert_response :success
      assert_select ".sales-chart-period a.is-active", text: "7 derniers jours"
    end

    test "renders the thirty day controlled period" do
      sign_in_as(create_admin_user)

      get admin_analytics_path(period: "30d")

      assert_response :success
      assert_select ".sales-chart-period a.is-active", text: "30 derniers jours"
    end

    test "sidebar includes the analytics link and marks it active" do
      sign_in_as(create_admin_user)

      get admin_analytics_path

      assert_select "a[href=?].admin-nav-link.is-active[aria-current='page']", admin_analytics_path, text: "Analytics"
    end

    private

    def without_ga4_configuration
      original_property_id = ENV.delete("GA4_PROPERTY_ID")
      original_credentials = ENV.delete("GOOGLE_APPLICATION_CREDENTIALS")
      yield
    ensure
      ENV["GA4_PROPERTY_ID"] = original_property_id if original_property_id
      ENV["GOOGLE_APPLICATION_CREDENTIALS"] = original_credentials if original_credentials
    end

    def with_ga4_dashboard(dashboard)
      singleton_class = Analytics::Ga4Dashboard.singleton_class
      original_new = singleton_class.instance_method(:new)
      singleton_class.define_method(:new) { |**| dashboard }
      yield
    ensure
      singleton_class.define_method(:new, original_new)
    end

    def ga4_comparisons
      { active_users: 12, sessions: 20, page_views: 45, product_views: 9, add_to_carts: 4, begin_checkouts: 3, purchases: 2, conversion_rate: 10.0 }
        .to_h { |name, value| [ name, Analytics::KpiComparison.build(current: value, previous: value) ] }
    end

    def funnel
      {
        steps: [
          { key: :sessions, label: "Sessions", count: 20, overall_rate: 100.0 },
          { key: :product_views, label: "Vues produit", count: 9, previous_rate: 45.0, overall_rate: 45.0, loss_rate: 55.0, previous_label: "Sessions" }
        ],
        biggest_drop: { key: :product_views, label: "Vues produit", previous_label: "Sessions", loss_rate: 55.0 }
      }
    end
  end
end

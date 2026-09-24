require "test_helper"

module Analytics
  class GrowthDashboardPayloadTest < ActiveSupport::TestCase
    test "serializes only aggregated official and behavioral dashboard data" do
      payload = GrowthDashboardPayload.new(
        local_report: local_report,
        ga4_report: ga4_report,
        insights: [ DashboardInsights::Insight.new(:watch, "À vérifier : un signal de test.") ],
        generated_at: Time.zone.parse("2026-09-07 12:00:00")
      ).as_json

      assert_equal "v1", payload.dig(:meta, :api_version)
      assert_equal "7d", payload.dig(:meta, :period)
      assert_equal "Europe/Paris", payload.dig(:meta, :timezone)
      assert_equal "available", payload.dig(:meta, :ga4_advanced_status)
      assert_nil payload.dig(:meta, :ga4_advanced_message)
      assert_equal "adura_database", payload.dig(:business, :source)
      assert_equal 124.5, payload.dig(:business, :revenue_eur)
      assert_equal "ga4", payload.dig(:ga4, :source)
      assert_equal 2, payload.dig(:funnel, :steps).size
      assert_equal "product_views", payload.dig(:funnel, :biggest_drop, :to)
      assert_equal "ADURA-YARA-100", payload.fetch(:products).first.fetch(:item_id)
      assert_equal "google", payload.fetch(:traffic_sources).first.fetch(:source)
      assert_equal "organic", payload.fetch(:traffic_sources).first.fetch(:medium)
      assert_equal "/parfums/yara", payload.fetch(:landing_pages).first.fetch(:landing_page)
      assert_equal "warning", payload.fetch(:insights).first.fetch(:severity)

      serialized = payload.to_json
      %w[email phone address stripe payment order_id].each { |key| refute_includes serialized, key }
    end

    private

    def local_report
      comparison = KpiComparison.build(current: 12_450, previous: 10_000)
      LocalDashboard::Report.new(
        "7d", Date.new(2026, 9, 1), Date.new(2026, 9, 7), 12_450, 3, 3, 4_150, 4, 1, 1, 0, 0, 0, 0, 0,
        [], [], {}, {}, [],
        { revenue_cents: comparison, orders_count: KpiComparison.build(current: 3, previous: 2), average_order_cents: comparison,
          items_sold_count: KpiComparison.build(current: 4, previous: 3) }
      )
    end

    def ga4_report
      funnel = {
        steps: [
          { key: :sessions, label: "Sessions", count: 100, previous_rate: nil, overall_rate: 100.0, loss_count: nil, loss_rate: nil },
          { key: :product_views, label: "Vues produit", count: 40, previous_key: :sessions, previous_rate: 40.0, overall_rate: 40.0, loss_count: 60, loss_rate: 60.0 }
        ],
        biggest_drop: { previous_key: :sessions, key: :product_views, loss_count: 60, loss_rate: 60.0 }
      }
      advanced = Ga4Dashboard::AdvancedReport.new(
        :available, nil, [], [], { started: 0, completed: 0 }, 0, funnel,
        [ { item_id: "ADURA-YARA-100", name: "Yara", views: 40, add_to_carts: 8, purchases: 2, revenue: 74.0, cart_rate: 20.0, purchase_rate: 5.0 } ],
        [ { name: "google / organic", sessions: 100, active_users: 80, purchases: 2, revenue: 74.0, conversion_rate: 2.0 } ],
        [ { path: "/parfums/yara", sessions: 100, active_users: 80, engagement_rate: 75.0, purchases: 2, revenue: 74.0, conversion_rate: 2.0 } ]
      )
      comparisons = {
        active_users: KpiComparison.build(current: 80, previous: 70),
        sessions: KpiComparison.build(current: 100, previous: 90),
        page_views: KpiComparison.build(current: 150, previous: 120),
        purchases: KpiComparison.build(current: 2, previous: 1),
        conversion_rate: KpiComparison.build(current: 2.0, previous: 1.0)
      }
      Ga4Dashboard::Report.new("7d", :available, nil, { active_users: 80, sessions: 100, page_views: 150, purchases: 2, conversion_rate: 2.0 }, [], [], [], advanced, comparisons)
    end
  end
end

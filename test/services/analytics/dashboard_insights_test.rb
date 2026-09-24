require "test_helper"

module Analytics
  class DashboardInsightsTest < ActiveSupport::TestCase
    test "returns cautious signals from the current GA4 report only" do
      report = report_with(
        kpis: { sessions: 25, product_views: 50, add_to_carts: 20, purchases: 1 },
        sources: [ { name: "google / organic", sessions: 20 } ],
        products: [ { name: "Yara", item_id: "ADURA-YARA-100", views: 50, add_to_carts: 2, purchases: 0, cart_rate: 4.0 } ],
        traffic_sources: [ { name: "TikTok / social", sessions: 30, purchases: 0, conversion_rate: 0 } ],
        landing_pages: [ { path: "/parfums/yara", sessions: 40, purchases: 0 } ],
        funnel: funnel_with_drop,
        quiz_usage: { started: 20, family_selected: 15, budget_selected: 12, completed: 5, completion_rate: 25.0 },
        search_usage: 15
      )

      messages = DashboardInsights.new(ga4_report: report).call.map(&:message)

      assert_operator messages.size, :>=, 7
      assert messages.any? { |message| message.include?("Yara") && message.include?("À vérifier") }
      assert messages.any? { |message| message.include?("ajouts au panier") }
      assert messages.any? { |message| message.include?("quiz") }
      assert messages.any? { |message| message.include?("recherche catalogue") }
      assert messages.any? { |message| message.include?("google / organic") }
      assert messages.any? { |message| message.include?("TikTok / social") }
      assert messages.any? { |message| message.include?("/parfums/yara") }
    end

    test "returns no signal when GA4 is unavailable" do
      report = Analytics::Ga4Dashboard::Report.new("today", :unavailable, nil, {}, [], [], [], unavailable_advanced, {})

      assert_empty DashboardInsights.new(ga4_report: report).call
    end

    test "keeps the new signals quiet below their minimum samples" do
      report = report_with(
        kpis: { sessions: 14, product_views: 9, add_to_carts: 1, purchases: 0 },
        sources: [],
        products: [ { name: "Yara", views: 9, add_to_carts: 0, purchases: 0, cart_rate: 0 } ],
        traffic_sources: [ { name: "TikTok / social", sessions: 24, purchases: 0, conversion_rate: 0 } ],
        landing_pages: [ { path: "/parfums/yara", sessions: 29, purchases: 0 } ],
        funnel: { steps: [], biggest_drop: { key: :add_to_carts, previous_count: 14, loss_rate: 90.0 } },
        quiz_usage: { started: 0, completed: 0 },
        search_usage: 0
      )

      assert_empty DashboardInsights.new(ga4_report: report).call
    end

    test "signals traffic growth with declining purchases and a converting source" do
      comparisons = {
        sessions: Analytics::KpiComparison.build(current: 30, previous: 20),
        purchases: Analytics::KpiComparison.build(current: 1, previous: 3)
      }
      report = report_with(
        kpis: { sessions: 30, purchases: 1, conversion_rate: 3.33 },
        sources: [],
        products: [],
        traffic_sources: [ { name: "Instagram / social", sessions: 30, purchases: 2, conversion_rate: 6.67 } ],
        landing_pages: [],
        funnel: { steps: [], biggest_drop: nil },
        quiz_usage: { started: 0, completed: 0 },
        search_usage: 0,
        comparisons: comparisons
      )

      messages = DashboardInsights.new(ga4_report: report).call.map(&:message)

      assert messages.any? { |message| message.include?("trafic augmente") }
      assert messages.any? { |message| message.include?("Instagram / social") && message.include?("au-dessus") }
    end

    test "signals product rates only with enough comparable product data" do
      report = report_with(
        kpis: { sessions: 40, purchases: 3 },
        sources: [],
        products: [
          { name: "Yara", views: 20, add_to_carts: 8, purchases: 3, cart_rate: 40.0, purchase_rate: 15.0 },
          { name: "Asad", views: 20, add_to_carts: 2, purchases: 1, cart_rate: 10.0, purchase_rate: 5.0 }
        ],
        traffic_sources: [],
        landing_pages: [],
        funnel: { steps: [], biggest_drop: nil },
        quiz_usage: { started: 0, completed: 0 },
        search_usage: 0
      )

      messages = DashboardInsights.new(ga4_report: report).call.map(&:message)

      assert messages.any? { |message| message.include?("Yara") && message.include?("ajouté au panier") }
      assert messages.any? { |message| message.include?("Yara") && message.include?("convertit") }
    end

    private

    def report_with(kpis:, sources:, products:, traffic_sources:, landing_pages:, funnel:, quiz_usage:, search_usage:, comparisons: {})
      complete_kpis = { active_users: 0, sessions: 0, page_views: 0, product_views: 0, add_to_carts: 0, begin_checkouts: 0, purchases: 0, conversion_rate: 0 }.merge(kpis)
      advanced = Analytics::Ga4Dashboard::AdvancedReport.new(:available, nil, products, products, quiz_usage, search_usage, funnel, products, traffic_sources, landing_pages)
      Analytics::Ga4Dashboard::Report.new("today", :available, nil, complete_kpis, sources, [], [], advanced, comparisons)
    end

    def unavailable_advanced
      Analytics::Ga4Dashboard::AdvancedReport.new(:unavailable, nil, [], [], {}, 0, { steps: [], biggest_drop: nil }, [], [], [])
    end

    def funnel_with_drop
      {
        steps: [ { key: :product_views, label: "Vues produit", count: 50 }, { key: :add_to_carts, label: "Ajouts panier", previous_label: "Vues produit", previous_count: 50, count: 2, loss_rate: 96.0 } ],
        biggest_drop: { key: :add_to_carts, label: "Ajouts panier", previous_label: "Vues produit", previous_count: 50, count: 2, loss_rate: 96.0 }
      }
    end
  end
end

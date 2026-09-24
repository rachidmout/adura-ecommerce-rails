require "test_helper"

module Analytics
  class Ga4DashboardTest < ActiveSupport::TestCase
    class FakeGa4Client
      attr_reader :calls

      def initialize(configured: true, error: nil, advanced_error: false, previous_end_date: nil)
        @configured = configured
        @error = error
        @advanced_error = advanced_error
        @previous_end_date = previous_end_date
        @calls = []
      end

      def configured?
        @configured
      end

      def property_id
        "123456789"
      end

      def run_report(**arguments)
        raise @error if @error

        calls << arguments
        case arguments.fetch(:dimensions)
        when []
          totals(arguments)
        when [ "eventName" ]
          event_rows(arguments.fetch(:event_names), zero: previous_period?(arguments))
        when %w[itemName itemId]
          raise Ga4Client::Unavailable if @advanced_error

          product_rows
        when [ "sessionSourceMedium" ]
          [ { "sessionSourceMedium" => "google / organic", "sessions" => "10", "activeUsers" => "8", "ecommercePurchases" => "2", "purchaseRevenue" => "74" } ]
        when [ "deviceCategory" ]
          [ { "deviceCategory" => "mobile", "sessions" => "14", "activeUsers" => "9" } ]
        when [ "country" ]
          [ { "country" => "France", "sessions" => "16", "activeUsers" => "11" } ]
        when [ "landingPage" ]
          raise Ga4Client::Unavailable if @advanced_error

          [ { "landingPage" => "/parfums/khamrah", "sessions" => "10", "activeUsers" => "8", "engagementRate" => "0.75", "ecommercePurchases" => "2", "purchaseRevenue" => "74" } ]
        else
          []
        end
      end

      private

      def totals(arguments)
        return [ { "activeUsers" => "0", "sessions" => "0", "screenPageViews" => "0", "ecommercePurchases" => "0" } ] if previous_period?(arguments)

        [ { "activeUsers" => "12", "sessions" => "20", "screenPageViews" => "45", "ecommercePurchases" => "2" } ]
      end

      def event_rows(event_names, zero: false)
        return event_names.map { |event_name| { "eventName" => event_name, "eventCount" => "0" } } if zero
        return [ { "eventName" => "view_item", "eventCount" => "9" }, { "eventName" => "add_to_cart", "eventCount" => "4" }, { "eventName" => "begin_checkout", "eventCount" => "3" } ] unless event_names.include?("quiz_started")

        [ { "eventName" => "quiz_started", "eventCount" => "8" }, { "eventName" => "quiz_family_selected", "eventCount" => "7" }, { "eventName" => "quiz_budget_selected", "eventCount" => "6" }, { "eventName" => "quiz_completed", "eventCount" => "4" }, { "eventName" => "search", "eventCount" => "5" } ]
      end

      def product_rows
        [ {
          "itemName" => "Yara",
          "itemId" => "ADURA-YARA-100",
          "itemsViewed" => "11",
          "itemsAddedToCart" => "6",
          "itemsPurchased" => "2",
          "itemRevenue" => "74"
        } ]
      end

      def previous_period?(arguments)
        @previous_end_date && arguments.fetch(:end_date) == @previous_end_date
      end
    end

    test "returns a safe fallback without calling GA4 when it is not configured" do
      client = FakeGa4Client.new(configured: false)
      report = Ga4Dashboard.new(period: "today", client: client, cache: ActiveSupport::Cache::MemoryStore.new).call

      assert_equal :not_configured, report.status
      assert_equal "Données GA4 non configurées.", report.message
      assert_empty client.calls
    end

    test "assembles and caches the essential GA4 reports for the requested period" do
      client = FakeGa4Client.new
      cache = ActiveSupport::Cache::MemoryStore.new
      dashboard = Ga4Dashboard.new(period: "7d", client: client, cache: cache, today: Date.new(2026, 8, 22))

      report = dashboard.call
      cached_report = dashboard.call

      assert_equal :available, report.status
      assert_equal 12, report.kpis[:active_users]
      assert_equal 20, report.kpis[:sessions]
      assert_equal 45, report.kpis[:page_views]
      assert_equal 9, report.kpis[:product_views]
      assert_equal 4, report.kpis[:add_to_carts]
      assert_equal 3, report.kpis[:begin_checkouts]
      assert_equal 2, report.kpis[:purchases]
      assert_equal 10.0, report.kpis[:conversion_rate]
      assert_equal "google / organic", report.sources.first[:name]
      assert_equal "mobile", report.devices.first[:name]
      assert_equal "France", report.countries.first[:name]
      assert_equal "Yara", report.advanced.top_product_views.first[:name]
      assert_equal "ADURA-YARA-100", report.advanced.top_product_views.first[:item_id]
      assert_equal 11, report.advanced.top_product_views.first[:views]
      assert_equal 6, report.advanced.top_cart_additions.first[:add_to_carts]
      assert_equal 2, report.advanced.products.first[:purchases]
      assert_equal 74.0, report.advanced.products.first[:revenue]
      assert_equal 54.55, report.advanced.products.first[:cart_rate]
      assert_equal 18.18, report.advanced.products.first[:purchase_rate]
      assert_equal :add_to_carts, report.advanced.funnel[:biggest_drop][:key]
      assert_equal 55.56, report.advanced.funnel[:biggest_drop][:loss_rate]
      assert_equal 2, report.advanced.traffic_sources.first[:purchases]
      assert_equal 74.0, report.advanced.traffic_sources.first[:revenue]
      assert_equal "/parfums/khamrah", report.advanced.landing_pages.first[:path]
      assert_equal 75.0, report.advanced.landing_pages.first[:engagement_rate]
      assert_equal 8, report.advanced.quiz_usage[:started]
      assert_equal 4, report.advanced.quiz_usage[:completed]
      assert_equal 50.0, report.advanced.quiz_usage[:completion_rate]
      assert_equal 5, report.advanced.search_usage
      assert_equal 10, client.calls.size
      assert_equal report, cached_report
      assert_equal Date.new(2026, 8, 16), client.calls.first.fetch(:start_date)
      assert_equal Date.new(2026, 8, 22), client.calls.first.fetch(:end_date)
      assert_equal %w[view_item add_to_cart begin_checkout], client.calls.second.fetch(:event_names)
      assert_equal %w[itemName itemId], client.calls[5].fetch(:dimensions)
      assert_equal %w[itemsViewed itemsAddedToCart itemsPurchased itemRevenue], client.calls[5].fetch(:metrics)
      assert_equal %w[quiz_started quiz_family_selected quiz_budget_selected quiz_completed search], client.calls[6].fetch(:event_names)
      assert_equal Date.new(2026, 8, 15), client.calls.last.fetch(:end_date)
      assert_equal :neutral, report.comparisons[:sessions].status
    end

    test "falls back to seven days for an invalid period" do
      client = FakeGa4Client.new
      report = Ga4Dashboard.new(period: "forever", client: client, cache: ActiveSupport::Cache::MemoryStore.new).call

      assert_equal "7d", report.period
    end

    test "uses the last successful report when the GA4 API is temporarily unavailable" do
      cache = ActiveSupport::Cache::MemoryStore.new
      successful_client = FakeGa4Client.new
      successful_report = Ga4Dashboard.new(period: "today", client: successful_client, cache: cache).call
      cache.delete("analytics/ga4/123456789/today/traffic-v1")
      failing_client = FakeGa4Client.new(error: Ga4Client::Unavailable)

      report = Ga4Dashboard.new(period: "today", client: failing_client, cache: cache).call

      assert_equal :stale, report.status
      assert_equal successful_report.kpis, report.kpis
      assert_match(/Dernières données disponibles/, report.message)
    end

    test "keeps compatible advanced reports when another advanced report fails" do
      cache = ActiveSupport::Cache::MemoryStore.new
      report = Ga4Dashboard.new(period: "today", client: FakeGa4Client.new(advanced_error: true), cache: cache).call

      assert report.available?
      assert_equal :partial, report.advanced.status
      assert_match(/products, landing_pages/, report.advanced.message)
      assert_equal 5, report.advanced.funnel[:steps].size
      assert_equal "google / organic", report.advanced.traffic_sources.first[:name]
      assert_empty report.advanced.products
      assert_empty report.advanced.landing_pages
    end

    test "labels GA4 comparisons as new when the previous period has no data" do
      today = Date.new(2026, 8, 22)
      client = FakeGa4Client.new(previous_end_date: Date.new(2026, 8, 15))
      report = Ga4Dashboard.new(period: "7d", client: client, cache: ActiveSupport::Cache::MemoryStore.new, today: today).call

      assert_equal :new, report.comparisons[:sessions].status
      assert_nil report.comparisons[:sessions].percent_change
    end

    test "builds a safe empty funnel when GA4 reports no sessions" do
      client = FakeGa4Client.new(previous_end_date: Date.new(2026, 8, 22))
      report = Ga4Dashboard.new(period: "today", client: client, cache: ActiveSupport::Cache::MemoryStore.new, today: Date.new(2026, 8, 22)).call

      assert_equal 0, report.advanced.funnel[:steps].first[:count]
      assert_nil report.advanced.funnel[:steps].second[:previous_rate]
      assert_nil report.advanced.funnel[:biggest_drop]
    end
  end
end

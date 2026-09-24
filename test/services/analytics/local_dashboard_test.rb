require "test_helper"

module Analytics
  class LocalDashboardTest < ActiveSupport::TestCase
    setup do
      @now = Time.zone.parse("2026-08-21 12:00:00")
    end

    test "calculates local paid order KPIs from immutable order and item snapshots" do
      product = create_publishable_product(slug: "local-analytics-product", price_cents: 2_000)
      promo = create_promo_code(code: "LOCAL20", discount_type: :fixed_amount, discount_value: 200)
      paid = create_paid_order(variant: product.product_variants.first)
      paid.update!(paid_at: @now, promo_code: promo, discount_cents: 200, total_cents: 2_290, shipping_cents: 490)
      paid.update_columns(country_code: "FR", shipping_method_name: "Livraison standard")

      shipped = create_paid_order(variant: product.product_variants.first, status: :shipped)
      shipped.update!(paid_at: @now, shipped_at: @now)
      shipped.update_columns(country_code: "BE", shipping_method_name: "Livraison Europe")

      preparing = create_paid_order(variant: product.product_variants.first, status: :paid)
      preparing.update_columns(status: "preparing", paid_at: @now, preparing_at: @now, country_code: "MA")

      cancelled = create_paid_order(variant: product.product_variants.first, status: :paid)
      cancelled.update_columns(status: "cancelled", paid_at: @now)

      old_order = create_paid_order(variant: product.product_variants.first)
      old_order.update_column(:paid_at, @now - 8.days)

      report = LocalDashboard.new(period: "7d", today: @now.to_date).call

      assert_equal "7d", report.period
      assert_equal 3, report.orders_count
      assert_equal 1, report.customers_count
      assert_equal 3, report.items_sold_count
      assert_equal 200, report.discount_cents
      assert_equal 1, report.promo_orders_count
      assert_equal 1_470, report.shipping_cents
      assert_equal 0, report.free_shipping_orders_count
      assert_equal 1, report.shipped_orders_count
      assert_equal 2, report.awaiting_shipment_count
      assert_equal 1, report.preparing_orders_count
      assert_equal 3, report.country_breakdown.values.sum
      assert_equal 1, report.country_breakdown.fetch("France")
      assert_equal 1, report.country_breakdown.fetch("Europe UE")
      assert_equal 1, report.country_breakdown.fetch("Maroc")
      assert_equal 2, report.shipping_method_breakdown.values.sum
      assert_equal product.name, report.top_products.first.fetch(:product_name)
      assert_equal 6_000, report.top_products.first.fetch(:revenue_cents)
      assert_equal "LOCAL20", report.top_promos.first.fetch(:code)
      assert_equal 200, report.top_promos.first.fetch(:discount_cents)
      assert_equal 7, report.daily_sales.size
      assert_equal :up, report.comparisons[:orders_count].status
      assert_equal 3, report.comparisons[:orders_count].current
      assert_equal 1, report.comparisons[:orders_count].previous
    end

    test "defaults invalid periods to seven days and keeps only the requested calendar range" do
      current_order = create_paid_order
      current_order.update_column(:paid_at, @now)
      old_order = create_paid_order
      old_order.update_column(:paid_at, @now - 7.days)

      report = LocalDashboard.new(period: "invalid", today: @now.to_date).call

      assert_equal "7d", report.period
      assert_equal @now.to_date - 6.days, report.starts_on
      assert_equal 1, report.orders_count
    end

    test "today limits sales and shipment metrics to the current day" do
      today_order = create_paid_order(status: :shipped)
      today_order.update_columns(paid_at: @now, shipped_at: @now)
      yesterday_order = create_paid_order(status: :shipped)
      yesterday_order.update_columns(paid_at: @now - 1.day, shipped_at: @now - 1.day)

      report = LocalDashboard.new(period: "today", today: @now.to_date).call

      assert_equal "today", report.period
      assert_equal 1, report.orders_count
      assert_equal 1, report.shipped_orders_count
      assert_equal 1, report.daily_sales.size
      assert_equal :neutral, report.comparisons[:orders_count].status
    end

    test "labels first activity as new instead of calculating a misleading percentage" do
      current_order = create_paid_order
      current_order.update_column(:paid_at, @now)

      report = LocalDashboard.new(period: "today", today: @now.to_date).call

      comparison = report.comparisons[:orders_count]
      assert_equal :new, comparison.status
      assert_nil comparison.percent_change
    end
  end
end

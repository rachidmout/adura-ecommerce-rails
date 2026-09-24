module Analytics
  class LocalDashboard
    PERIODS = {
      "today" => 0,
      "7d" => 6,
      "30d" => 29
    }.freeze
    EUROPEAN_UNION_COUNTRIES = %w[BE LU NL DE ES PT IT].freeze

    Report = Data.define(
      :period,
      :starts_on,
      :ends_on,
      :revenue_cents,
      :orders_count,
      :customers_count,
      :average_order_cents,
      :items_sold_count,
      :shipped_orders_count,
      :awaiting_shipment_count,
      :preparing_orders_count,
      :discount_cents,
      :promo_orders_count,
      :shipping_cents,
      :free_shipping_orders_count,
      :top_products,
      :top_promos,
      :country_breakdown,
      :shipping_method_breakdown,
      :daily_sales,
      :comparisons
    )

    def self.valid_period?(period)
      PERIODS.key?(period.to_s)
    end

    def initialize(period:, today: Date.current)
      @period = self.class.valid_period?(period) ? period.to_s : "7d"
      @today = today
    end

    def call
      orders = Order.completed.where(paid_at: paid_at_range)
      items = OrderItem.joins(:order).merge(orders)
      previous_orders = Order.completed.where(paid_at: previous_paid_at_range)
      previous_items = OrderItem.joins(:order).merge(previous_orders)
      revenue_cents = orders.sum(:total_cents)
      orders_count = orders.count

      Report.new(
        period: period,
        starts_on: starts_on,
        ends_on: today,
        revenue_cents: revenue_cents,
        orders_count: orders_count,
        customers_count: orders.distinct.count(:email),
        average_order_cents: orders_count.positive? ? revenue_cents / orders_count : 0,
        items_sold_count: items.sum(:quantity),
        shipped_orders_count: Order.completed.where(shipped_at: paid_at_range).count,
        awaiting_shipment_count: orders.awaiting_shipment.count,
        preparing_orders_count: orders.preparing.count,
        discount_cents: orders.sum(:discount_cents),
        promo_orders_count: orders.where.not(promo_code_id: nil).count,
        shipping_cents: orders.sum(:shipping_cents),
        free_shipping_orders_count: orders.where(shipping_cents: 0).count,
        top_products: top_products(items),
        top_promos: top_promos(orders),
        country_breakdown: country_breakdown(orders),
        shipping_method_breakdown: orders.where.not(shipping_method_name: nil).group(:shipping_method_name).count,
        daily_sales: daily_sales(orders),
        comparisons: comparisons_for(
          revenue_cents: revenue_cents,
          orders_count: orders_count,
          average_order_cents: orders_count.positive? ? revenue_cents / orders_count : 0,
          items_sold_count: items.sum(:quantity),
          previous_orders: previous_orders,
          previous_items: previous_items
        )
      )
    end

    private

    attr_reader :period, :today

    def starts_on
      today - PERIODS.fetch(period)
    end

    def paid_at_range
      starts_on.beginning_of_day..today.end_of_day
    end

    def previous_starts_on
      starts_on - period_length
    end

    def previous_ends_on
      starts_on - 1.day
    end

    def previous_paid_at_range
      previous_starts_on.beginning_of_day..previous_ends_on.end_of_day
    end

    def period_length
      PERIODS.fetch(period) + 1
    end

    def comparisons_for(revenue_cents:, orders_count:, average_order_cents:, items_sold_count:, previous_orders:, previous_items:)
      previous_revenue_cents = previous_orders.sum(:total_cents)
      previous_orders_count = previous_orders.count
      {
        revenue_cents: KpiComparison.build(current: revenue_cents, previous: previous_revenue_cents),
        orders_count: KpiComparison.build(current: orders_count, previous: previous_orders_count),
        average_order_cents: KpiComparison.build(
          current: average_order_cents,
          previous: previous_orders_count.positive? ? previous_revenue_cents / previous_orders_count : 0
        ),
        items_sold_count: KpiComparison.build(current: items_sold_count, previous: previous_items.sum(:quantity))
      }
    end

    def top_products(items)
      items.group(:brand_name, :product_name)
           .order(Arel.sql("SUM(quantity) DESC"), :product_name)
           .limit(5)
           .pluck(
             :brand_name,
             :product_name,
             Arel.sql("SUM(quantity)"),
             Arel.sql("SUM(line_total_cents)")
           )
           .map do |brand_name, product_name, quantity, revenue_cents|
        { brand_name: brand_name, product_name: product_name, quantity: quantity, revenue_cents: revenue_cents }
      end
    end

    def top_promos(orders)
      orders.where.not(promo_code_id: nil)
            .joins(:promo_code)
            .group("promo_codes.code")
            .order(Arel.sql("COUNT(orders.id) DESC"), Arel.sql("promo_codes.code ASC"))
            .limit(5)
            .pluck(Arel.sql("promo_codes.code"), Arel.sql("COUNT(orders.id)"), Arel.sql("SUM(orders.discount_cents)"))
            .map do |code, uses_count, discount_cents|
        { code: code, uses_count: uses_count, discount_cents: discount_cents }
      end
    end

    def country_breakdown(orders)
      grouped = Hash.new(0)
      orders.group(:country_code).count.each do |country_code, count|
        grouped[country_group(country_code)] += count
      end
      grouped
    end

    def country_group(country_code)
      return "France" if country_code == "FR"
      return "Europe UE" if EUROPEAN_UNION_COUNTRIES.include?(country_code)
      return "Maroc" if country_code == "MA"

      "Autres destinations"
    end

    def daily_sales(orders)
      totals_by_day = orders.pluck(:paid_at, :total_cents).each_with_object(Hash.new(0)) do |(paid_at, total_cents), totals|
        totals[paid_at.in_time_zone.to_date] += total_cents
      end

      (starts_on..today).map { |date| [ date, totals_by_day[date] ] }
    end
  end
end

module Analytics
  class GrowthDashboardPayload
    def initialize(local_report:, ga4_report:, insights:, generated_at: Time.current)
      @local_report = local_report
      @ga4_report = ga4_report
      @insights = insights
      @generated_at = generated_at
    end

    def as_json(*)
      {
        meta: meta,
        business: business,
        ga4: ga4,
        funnel: funnel,
        products: products,
        traffic_sources: traffic_sources,
        landing_pages: landing_pages,
        insights: insights
      }
    end

    private

    attr_reader :local_report, :ga4_report, :insights, :generated_at

    def meta
      {
        api_version: "v1",
        period: local_report.period,
        start_date: local_report.starts_on.iso8601,
        end_date: local_report.ends_on.iso8601,
        generated_at: generated_at.iso8601,
        timezone: Time.zone.tzinfo.name,
        ga4_status: ga4_report.status.to_s,
        ga4_fallback: ga4_report.status == :stale,
        ga4_advanced_status: ga4_report.advanced.status.to_s,
        ga4_advanced_message: ga4_report.advanced.message
      }
    end

    def business
      {
        source: "adura_database",
        revenue_eur: amount(local_report.revenue_cents),
        orders: local_report.orders_count,
        paid_orders: local_report.orders_count,
        average_order_value_eur: amount(local_report.average_order_cents),
        customers: local_report.customers_count,
        items_sold: local_report.items_sold_count,
        comparison: {
          revenue: comparison(local_report.comparisons[:revenue_cents], cents: true),
          orders: comparison(local_report.comparisons[:orders_count]),
          average_order_value: comparison(local_report.comparisons[:average_order_cents], cents: true),
          items_sold: comparison(local_report.comparisons[:items_sold_count])
        }
      }
    end

    def ga4
      {
        source: "ga4",
        status: ga4_report.status.to_s,
        users: ga4_report.kpis[:active_users],
        sessions: ga4_report.kpis[:sessions],
        page_views: ga4_report.kpis[:page_views],
        purchases: ga4_report.kpis[:purchases],
        conversion_rate: ga4_report.kpis[:conversion_rate],
        comparison: {
          users: comparison(ga4_report.comparisons[:active_users]),
          sessions: comparison(ga4_report.comparisons[:sessions]),
          page_views: comparison(ga4_report.comparisons[:page_views]),
          purchases: comparison(ga4_report.comparisons[:purchases]),
          conversion_rate: comparison(ga4_report.comparisons[:conversion_rate])
        }
      }
    end

    def funnel
      report = ga4_report.advanced.funnel
      {
        steps: report[:steps].map { |step| funnel_step(step) },
        biggest_drop: biggest_drop(report[:biggest_drop])
      }
    end

    def products
      ga4_report.advanced.products.map do |product|
        {
          item_id: product[:item_id],
          item_name: product[:name],
          views: product[:views],
          add_to_cart: product[:add_to_carts],
          purchases_ga4: product[:purchases],
          item_revenue_ga4_eur: product[:revenue],
          add_to_cart_rate: product[:cart_rate],
          purchase_rate: product[:purchase_rate]
        }
      end
    end

    def traffic_sources
      ga4_report.advanced.traffic_sources.map do |source|
        name, medium = source[:name].to_s.split(" / ", 2)
        {
          source: name,
          medium: medium,
          source_medium: source[:name],
          sessions: source[:sessions],
          users: source[:active_users],
          purchases_ga4: source[:purchases],
          conversion_rate: source[:conversion_rate],
          revenue_ga4_eur: source[:revenue]
        }
      end
    end

    def landing_pages
      ga4_report.advanced.landing_pages.map do |landing_page|
        {
          landing_page: landing_page[:path],
          sessions: landing_page[:sessions],
          users: landing_page[:active_users],
          engagement_rate: landing_page[:engagement_rate],
          purchases_ga4: landing_page[:purchases],
          conversion_rate: landing_page[:conversion_rate],
          revenue_ga4_eur: landing_page[:revenue]
        }
      end
    end

    def insights
      @insights.map do |insight|
        {
          type: insight.kind.to_s,
          severity: insight.kind == :watch ? "warning" : "notice",
          message: insight.message
        }
      end
    end

    def funnel_step(step)
      {
        name: step[:key].to_s,
        label: step[:label],
        count: step[:count],
        pass_rate: step[:previous_rate],
        overall_rate: step[:overall_rate],
        loss: step[:loss_count],
        loss_rate: step[:loss_rate]
      }
    end

    def biggest_drop(step)
      return if step.nil?

      {
        from: step[:previous_key].to_s,
        to: step[:key].to_s,
        loss: step[:loss_count],
        loss_rate: step[:loss_rate]
      }
    end

    def comparison(value, cents: false)
      return { status: "not_available", current: nil, previous: nil, percent_change: nil } if value.nil?

      {
        status: value.status.to_s,
        current: cents ? amount(value.current) : value.current,
        previous: cents && value.previous ? amount(value.previous) : value.previous,
        percent_change: value.percent_change
      }
    end

    def amount(cents)
      cents.to_i.fdiv(100).round(2)
    end
  end
end

module Analytics
  class Ga4Dashboard
    CACHE_TTLS = {
      "today" => 15.minutes,
      "7d" => 1.hour,
      "30d" => 3.hours
    }.freeze

    # Toutes les données comportementales du dashboard sont regroupées ici :
    # la vue et, plus tard, une API interne pourront donc consommer la même
    # structure sans devoir reconstruire des calculs GA4.
    AdvancedReport = Data.define(
      :status,
      :message,
      :top_product_views,
      :top_cart_additions,
      :quiz_usage,
      :search_usage,
      :funnel,
      :products,
      :traffic_sources,
      :landing_pages
    ) do
      def available?
        status.in?(%i[available partial stale])
      end
    end

    Report = Data.define(:period, :status, :message, :kpis, :sources, :devices, :countries, :advanced, :comparisons) do
      def available?
        status.in?(%i[available stale])
      end
    end

    def initialize(period:, client: Ga4Client.new, cache: Rails.cache, today: Date.current)
      @period = LocalDashboard.valid_period?(period) ? period.to_s : "7d"
      @client = client
      @cache = cache
      @today = today
    end

    def call
      return not_configured unless client.configured?

      traffic = cache.fetch(traffic_cache_key, expires_in: CACHE_TTLS.fetch(period)) { fetch_and_remember_traffic }
      @kpis = traffic.kpis
      Report.new(traffic.period, traffic.status, traffic.message, traffic.kpis, traffic.sources, traffic.devices, traffic.countries, advanced_report, comparisons_for(traffic.kpis))
    rescue StandardError => error
      Rails.logger.warn("GA4 dashboard unavailable: #{error.class}") unless error.is_a?(Ga4Client::Unavailable)
      cached_report || unavailable
    end

    private

    attr_reader :period, :client, :cache, :today

    def not_configured
      Report.new(period, :not_configured, "Données GA4 non configurées.", empty_kpis, [], [], [], advanced_not_configured, empty_comparisons)
    end

    def unavailable
      Report.new(period, :unavailable, "Données GA4 temporairement indisponibles.", empty_kpis, [], [], [], advanced_unavailable, empty_comparisons)
    end

    def cached_report
      report = cache.read(last_success_cache_key)
      return unless report

      Report.new(report.period, :stale, "Données GA4 temporairement indisponibles. Dernières données disponibles affichées.", report.kpis, report.sources, report.devices, report.countries, advanced_report, comparisons_for(report.kpis))
    end

    def fetch_and_remember_traffic
      report = Report.new(period, :available, nil, kpis, sources, devices, countries, nil, nil)
      cache.write(last_success_cache_key, report, expires_in: 24.hours)
      report
    end

    def advanced_report
      cache.fetch(advanced_cache_key, expires_in: CACHE_TTLS.fetch(period)) { fetch_and_remember_advanced }
    rescue StandardError => error
      Rails.logger.warn("GA4 advanced analytics unavailable: #{error.class}") unless error.is_a?(Ga4Client::Unavailable)
      cached_advanced_report || advanced_unavailable
    end

    def fetch_and_remember_advanced
      unavailable_reports = []
      products = advanced_value(:products, unavailable_reports, []) { product_metrics }
      events = advanced_value(:events, unavailable_reports, {}) { advanced_events }
      sources = advanced_value(:traffic_sources, unavailable_reports, []) { traffic_sources }
      pages = advanced_value(:landing_pages, unavailable_reports, []) { landing_pages }
      report = AdvancedReport.new(
        unavailable_reports.any? ? :partial : :available,
        advanced_partial_message(unavailable_reports),
        products.sort_by { |row| -row[:views] }.first(5),
        products.sort_by { |row| -row[:add_to_carts] }.first(5),
        quiz_usage(events),
        search_usage(events),
        funnel,
        products,
        sources,
        pages
      )
      cache.write(last_success_advanced_cache_key, report, expires_in: 24.hours)
      report
    end

    def cached_advanced_report
      report = cache.read(last_success_advanced_cache_key)
      return unless report

      AdvancedReport.new(
        :stale,
        "Données e-commerce GA4 temporairement indisponibles. Dernières données disponibles affichées.",
        report.top_product_views,
        report.top_cart_additions,
        report.quiz_usage,
        report.search_usage,
        report.funnel,
        report.products,
        report.traffic_sources,
        report.landing_pages
      )
    end

    def advanced_not_configured
      AdvancedReport.new(:not_configured, "Données GA4 non configurées.", [], [], empty_quiz_usage, 0, empty_funnel, [], [], [])
    end

    def advanced_unavailable
      AdvancedReport.new(:unavailable, "Données e-commerce GA4 temporairement indisponibles.", [], [], empty_quiz_usage, 0, empty_funnel, [], [], [])
    end

    def kpis
      @kpis ||= kpis_for(start_date: starts_on, end_date: today)
    end

    def kpis_for(start_date:, end_date:)
      totals = client.run_report(
        dimensions: [],
        metrics: %w[activeUsers sessions screenPageViews ecommercePurchases],
        start_date: start_date,
        end_date: end_date,
        limit: 1
      ).first || {}
      events = client.run_report(
        dimensions: [ "eventName" ],
        metrics: [ "eventCount" ],
        start_date: start_date,
        end_date: end_date,
        event_names: %w[view_item add_to_cart begin_checkout],
        limit: 3
      ).index_by { |row| row["eventName"] }
      sessions = integer(totals["sessions"])
      purchases = integer(totals["ecommercePurchases"])

      {
        active_users: integer(totals["activeUsers"]),
        sessions: sessions,
        page_views: integer(totals["screenPageViews"]),
        product_views: integer(events.dig("view_item", "eventCount")),
        add_to_carts: integer(events.dig("add_to_cart", "eventCount")),
        begin_checkouts: integer(events.dig("begin_checkout", "eventCount")),
        purchases: purchases,
        conversion_rate: sessions.positive? ? (purchases.fdiv(sessions) * 100).round(2) : 0
      }
    end

    def sources
      traffic_sources
    end

    def devices
      dimension_report("deviceCategory")
    end

    def countries
      dimension_report("country")
    end

    def dimension_report(dimension)
      client.run_report(
        dimensions: [ dimension ],
        metrics: %w[sessions activeUsers],
        start_date: starts_on,
        end_date: today,
        limit: 5
      ).map do |row|
        { name: row[dimension].presence || "Non renseigné", sessions: integer(row["sessions"]), active_users: integer(row["activeUsers"]) }
      end
    end

    # `item*` et les métriques e-commerce sont des dimensions/métriques
    # officielles de la Data API. `itemsViewed` est la métrique item-scoped
    # compatible avec itemName/itemId ; itemViewEvents ne l'est pas.
    # Une seule requête rassemble les vues,
    # ajouts, achats et revenu par SKU, plutôt que plusieurs rapports qui
    # pourraient diverger entre eux.
    def product_metrics
      client.run_report(
        dimensions: %w[itemName itemId],
        metrics: %w[itemsViewed itemsAddedToCart itemsPurchased itemRevenue],
        start_date: starts_on,
        end_date: today,
        limit: 10
      ).filter_map do |row|
        views = integer(row["itemsViewed"])
        additions = integer(row["itemsAddedToCart"])
        purchases = integer(row["itemsPurchased"])
        revenue = decimal(row["itemRevenue"])
        next if views.zero? && additions.zero? && purchases.zero? && revenue.zero?

        {
          name: row["itemName"].presence || "Produit non renseigné",
          item_id: row["itemId"].presence || "—",
          views: views,
          add_to_carts: additions,
          purchases: purchases,
          revenue: revenue,
          cart_rate: rate(additions, views),
          purchase_rate: rate(purchases, views)
        }
      end
    end

    def traffic_sources
      @traffic_sources ||= client.run_report(
        dimensions: [ "sessionSourceMedium" ],
        metrics: %w[sessions activeUsers ecommercePurchases purchaseRevenue],
        start_date: starts_on,
        end_date: today,
        limit: 8
      ).map do |row|
        sessions = integer(row["sessions"])
        purchases = integer(row["ecommercePurchases"])
        {
          name: row["sessionSourceMedium"].presence || "Non renseigné",
          sessions: sessions,
          active_users: integer(row["activeUsers"]),
          purchases: purchases,
          revenue: decimal(row["purchaseRevenue"]),
          conversion_rate: rate(purchases, sessions)
        }
      end
    end

    # `landingPage` exclut volontairement la query string afin de ne jamais
    # afficher une recherche ou un paramètre potentiellement sensible dans
    # l'administration.
    def landing_pages
      @landing_pages ||= client.run_report(
        dimensions: [ "landingPage" ],
        metrics: %w[sessions activeUsers engagementRate ecommercePurchases purchaseRevenue],
        start_date: starts_on,
        end_date: today,
        limit: 10
      ).map do |row|
        sessions = integer(row["sessions"])
        purchases = integer(row["ecommercePurchases"])
        {
          path: row["landingPage"].presence || "Non renseignée",
          sessions: sessions,
          active_users: integer(row["activeUsers"]),
          engagement_rate: percentage(row["engagementRate"]),
          purchases: purchases,
          revenue: decimal(row["purchaseRevenue"]),
          conversion_rate: rate(purchases, sessions)
        }
      end
    end

    def funnel
      previous_count = nil
      previous_step = nil
      session_count = kpis[:sessions]
      steps = [
        [ :sessions, "Sessions", session_count ],
        [ :product_views, "Vues produit", kpis[:product_views] ],
        [ :add_to_carts, "Ajouts panier", kpis[:add_to_carts] ],
        [ :begin_checkouts, "Débuts checkout", kpis[:begin_checkouts] ],
        [ :purchases, "Achats GA4", kpis[:purchases] ]
      ].map do |key, label, count|
        step = {
          key: key,
          label: label,
          count: count.to_i,
          previous_key: previous_step&.fetch(:key),
          previous_label: previous_step&.fetch(:label),
          previous_count: previous_count,
          previous_rate: previous_count.nil? ? nil : rate(count, previous_count),
          overall_rate: rate(count, session_count),
          loss_count: previous_count.nil? ? nil : [ previous_count - count.to_i, 0 ].max,
          loss_rate: previous_count.nil? ? nil : loss_rate(count, previous_count)
        }
        previous_count = count.to_i
        previous_step = step
        step
      end

      losses = steps.drop(1).select { |step| step[:loss_rate].present? }
      { steps: steps, biggest_drop: losses.max_by { |step| step[:loss_rate] } }
    end

    def quiz_usage(events = advanced_events)
      {
        started: integer(events.dig("quiz_started", "eventCount")),
        family_selected: integer(events.dig("quiz_family_selected", "eventCount")),
        budget_selected: integer(events.dig("quiz_budget_selected", "eventCount")),
        completed: integer(events.dig("quiz_completed", "eventCount")),
        completion_rate: quiz_completion_rate(events)
      }
    end

    def search_usage(events = advanced_events)
      integer(events.dig("search", "eventCount"))
    end

    def advanced_events
      @advanced_events ||= client.run_report(
        dimensions: [ "eventName" ],
        metrics: [ "eventCount" ],
        start_date: starts_on,
        end_date: today,
        event_names: %w[quiz_started quiz_family_selected quiz_budget_selected quiz_completed search],
        limit: 5
      ).index_by { |row| row["eventName"] }
    end

    def quiz_completion_rate(events)
      started = integer(events.dig("quiz_started", "eventCount"))
      return 0 unless started.positive?

      (integer(events.dig("quiz_completed", "eventCount")).fdiv(started) * 100).round(2)
    end

    def starts_on
      today - LocalDashboard::PERIODS.fetch(period)
    end

    def previous_starts_on
      starts_on - period_length
    end

    def previous_ends_on
      starts_on - 1.day
    end

    def period_length
      LocalDashboard::PERIODS.fetch(period) + 1
    end

    def comparisons_for(current_kpis)
      previous_kpis = cache.fetch(previous_kpis_cache_key, expires_in: CACHE_TTLS.fetch(period)) { fetch_and_remember_previous_kpis }
      current_kpis.each_with_object({}) do |(name, value), comparisons|
        comparisons[name] = KpiComparison.build(current: value, previous: previous_kpis.fetch(name))
      end
    rescue StandardError => error
      Rails.logger.warn("GA4 comparison unavailable: #{error.class}") unless error.is_a?(Ga4Client::Unavailable)
      empty_comparisons(current_kpis)
    end

    def fetch_and_remember_previous_kpis
      kpis_for(start_date: previous_starts_on, end_date: previous_ends_on)
    end

    def traffic_cache_key
      cache_key("traffic-v1")
    end

    def last_success_cache_key
      "#{traffic_cache_key}/last-success"
    end

    def advanced_cache_key
      cache_key("advanced-ecommerce-v2")
    end

    def last_success_advanced_cache_key
      "#{advanced_cache_key}/last-success"
    end

    def previous_kpis_cache_key
      cache_key("previous-kpis-v1/#{previous_ends_on.iso8601}")
    end

    def cache_key(report_type)
      "analytics/ga4/#{client.property_id}/#{period}/#{report_type}"
    end

    def empty_kpis
      { active_users: 0, sessions: 0, page_views: 0, product_views: 0, add_to_carts: 0, begin_checkouts: 0, purchases: 0, conversion_rate: 0 }
    end

    def empty_comparisons(kpis = empty_kpis)
      kpis.to_h { |name, value| [ name, KpiComparison.build(current: value, previous: nil) ] }
    end

    def empty_quiz_usage
      { started: 0, family_selected: 0, budget_selected: 0, completed: 0, completion_rate: 0 }
    end

    def empty_funnel
      { steps: [], biggest_drop: nil }
    end

    def advanced_value(name, unavailable_reports, fallback)
      yield
    rescue StandardError => error
      Rails.logger.warn("GA4 #{name} report unavailable: #{error.class}") unless error.is_a?(Ga4Client::Unavailable)
      unavailable_reports << name
      fallback
    end

    def advanced_partial_message(unavailable_reports)
      return if unavailable_reports.empty?

      "Certains rapports e-commerce GA4 sont temporairement indisponibles : #{unavailable_reports.join(', ')}."
    end

    def integer(value)
      value.to_i
    end

    def decimal(value)
      value.to_f.round(2)
    end

    def percentage(value)
      (value.to_f * 100).round(2)
    end

    def rate(numerator, denominator)
      return nil unless denominator.to_i.positive?

      (numerator.to_f.fdiv(denominator) * 100).round(2)
    end

    def loss_rate(current, previous)
      return nil unless previous.to_i.positive?

      ([ previous.to_i - current.to_i, 0 ].max.fdiv(previous) * 100).round(2)
    end
  end
end

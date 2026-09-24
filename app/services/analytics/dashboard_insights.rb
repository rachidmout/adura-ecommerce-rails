module Analytics
  class DashboardInsights
    Insight = Data.define(:kind, :message)

    MINIMUM_PRODUCT_VIEWS = 10
    MINIMUM_CART_ADDITIONS = 10
    MINIMUM_QUIZ_STARTS = 10
    MINIMUM_SEARCHES = 10
    MINIMUM_FUNNEL_STEP = 15
    MINIMUM_SOURCE_SESSIONS = 25
    MINIMUM_LANDING_SESSIONS = 30
    LOW_PRODUCT_CART_RATE_PERCENT = 10.0
    LOW_PRODUCT_PURCHASE_RATE_PERCENT = 20.0
    LOW_CART_PURCHASE_RATE = 0.2
    LOW_QUIZ_COMPLETION_RATE = 0.5
    DOMINANT_SOURCE_RATE = 0.6
    HIGH_FUNNEL_LOSS_RATE = 0.6
    TRAFFIC_GROWTH_RATE = 0.2
    PURCHASE_DECLINE_RATE = -0.2

    def initialize(ga4_report:)
      @ga4_report = ga4_report
    end

    def call
      return [] unless ga4_report.available? && ga4_report.advanced.available?

      [
        funnel_signal,
        traffic_decline_signal,
        product_interest_signal,
        product_purchase_signal,
        product_cart_signal,
        product_conversion_signal,
        cart_signal,
        source_without_purchase_signal,
        source_conversion_signal,
        landing_page_signal,
        quiz_signal,
        search_signal,
        source_signal
      ].compact
    end

    private

    attr_reader :ga4_report

    def product_interest_signal
      product = ga4_report.advanced.products.find do |row|
        row[:views] >= MINIMUM_PRODUCT_VIEWS && row[:cart_rate].to_f < LOW_PRODUCT_CART_RATE_PERCENT
      end
      return unless product

      Insight.new(:watch, "À vérifier : #{product[:name]} est beaucoup consulté mais semble peu ajouté au panier.")
    end

    def product_purchase_signal
      product = ga4_report.advanced.products.find do |row|
        row[:views] >= MINIMUM_PRODUCT_VIEWS && row[:purchases].zero?
      end
      return unless product

      Insight.new(:watch, "À vérifier : #{product[:name]} est beaucoup consulté mais ne génère aucun achat GA4 sur cette période.")
    end

    def product_cart_signal
      products = measurable_products
      average = average_rate(products, :cart_rate)
      product = products.max_by { |row| row[:cart_rate].to_f }
      return unless product && average && product[:cart_rate].to_f > average

      Insight.new(:notice, "Signal positif : #{product[:name]} est ajouté au panier au-dessus de la moyenne des produits observés.")
    end

    def product_conversion_signal
      products = measurable_products.select { |row| row[:purchases].positive? }
      average = average_rate(products, :purchase_rate)
      product = products.max_by { |row| row[:purchase_rate].to_f }
      return unless product && average && product[:purchase_rate].to_f > average

      Insight.new(:notice, "Signal positif : #{product[:name]} convertit au-dessus de la moyenne des produits observés.")
    end

    def cart_signal
      additions = ga4_report.kpis[:add_to_carts]
      purchases = ga4_report.kpis[:purchases]
      return unless additions >= MINIMUM_CART_ADDITIONS && purchases.fdiv(additions) < LOW_CART_PURCHASE_RATE

      Insight.new(:watch, "À vérifier : les ajouts au panier aboutissent peu à un achat GA4 sur cette période.")
    end

    def quiz_signal
      quiz = ga4_report.advanced.quiz_usage
      return unless quiz[:started] >= MINIMUM_QUIZ_STARTS && quiz[:completed].fdiv(quiz[:started]) < LOW_QUIZ_COMPLETION_RATE

      Insight.new(:watch, "À vérifier : le quiz est souvent commencé mais peu terminé.")
    end

    def search_signal
      return unless ga4_report.advanced.search_usage >= MINIMUM_SEARCHES

      Insight.new(:notice, "La recherche catalogue est fréquemment utilisée ; cela peut indiquer un besoin de repérage plus direct.")
    end

    def source_signal
      source = ga4_report.sources.first
      sessions = ga4_report.kpis[:sessions]
      return unless source && sessions.positive? && source[:sessions].fdiv(sessions) >= DOMINANT_SOURCE_RATE

      Insight.new(:notice, "Source dominante : #{source[:name]} représente une part importante des sessions.")
    end

    def funnel_signal
      drop = ga4_report.advanced.funnel[:biggest_drop]
      return unless drop && drop[:previous_count].to_i >= MINIMUM_FUNNEL_STEP && drop[:loss_rate].to_f >= HIGH_FUNNEL_LOSS_RATE * 100

      Insight.new(:watch, "À vérifier : la plus forte perte du funnel se situe entre « #{drop[:previous_label]} » et « #{drop[:label]} » (#{drop[:loss_rate]} %).")
    end

    def traffic_decline_signal
      sessions = ga4_report.comparisons[:sessions]
      purchases = ga4_report.comparisons[:purchases]
      return unless sessions&.percent_change && purchases&.percent_change
      return unless sessions.percent_change >= TRAFFIC_GROWTH_RATE * 100 && purchases.percent_change <= PURCHASE_DECLINE_RATE * 100

      Insight.new(:watch, "À vérifier : le trafic augmente mais les achats GA4 diminuent par rapport à la période précédente.")
    end

    def source_without_purchase_signal
      source = ga4_report.advanced.traffic_sources.find do |row|
        row[:sessions] >= MINIMUM_SOURCE_SESSIONS && row[:purchases].zero?
      end
      return unless source

      Insight.new(:watch, "À vérifier : #{source[:name]} apporte du trafic mais aucun achat GA4 sur cette période.")
    end

    def source_conversion_signal
      average = ga4_report.kpis[:conversion_rate].to_f
      source = ga4_report.advanced.traffic_sources.find do |row|
        row[:sessions] >= MINIMUM_SOURCE_SESSIONS && row[:purchases].positive? && row[:conversion_rate].to_f > average
      end
      return unless source

      Insight.new(:notice, "Signal positif : #{source[:name]} convertit au-dessus de la moyenne GA4 sur cette période.")
    end

    def landing_page_signal
      landing = ga4_report.advanced.landing_pages.find do |row|
        row[:sessions] >= MINIMUM_LANDING_SESSIONS && row[:purchases].zero?
      end
      return unless landing

      Insight.new(:watch, "À vérifier : la landing page #{landing[:path]} reçoit du trafic mais aucun achat GA4.")
    end

    def measurable_products
      ga4_report.advanced.products.select { |row| row[:views] >= MINIMUM_PRODUCT_VIEWS }
    end

    def average_rate(products, key)
      return if products.size < 2

      (products.sum { |row| row[key].to_f } / products.size).round(2)
    end
  end
end

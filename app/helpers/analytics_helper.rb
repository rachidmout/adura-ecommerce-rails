module AnalyticsHelper
  GA4_MEASUREMENT_ID_PATTERN = /\AG-[A-Z0-9]+\z/.freeze
  QUIZ_BUDGET_RANGES = %w[under_30 30_40 40_50 50_plus open].freeze
  CATALOG_PRICE_FILTERS = %w[2000 2500 3500].freeze

  # La configuration reste entièrement dans l'environnement : aucun
  # identifiant Google n'est versionné ni injecté si la variable est absente
  # ou mal formée.
  def ga4_measurement_id
    measurement_id = ENV.fetch("GA4_MEASUREMENT_ID", "").strip
    measurement_id if GA4_MEASUREMENT_ID_PATTERN.match?(measurement_id)
  end

  def analytics_configured?
    ga4_measurement_id.present?
  end

  # Les données ecommerce exposées dans le HTML viennent exclusivement des
  # objets Rails affichés. Cette liste volontairement fermée exclut toutes les
  # données client et les valeurs de paiement.
  def analytics_ecommerce_item(product:, variant:, quantity: nil)
    {
      item_id: variant&.sku.presence || product.slug,
      item_name: product.name,
      item_brand: product.brand.name,
      item_category: translated_family_name(product.primary_family),
      item_variant: variant&.label,
      price: analytics_euros(variant&.price_cents),
      quantity: quantity
    }.compact
  end

  def analytics_ecommerce_event(items:, value_cents:, **attributes)
    {
      currency: "EUR",
      value: analytics_euros(value_cents),
      items: items
    }.merge(attributes).compact
  end

  # Un achat est toujours reconstruit depuis les snapshots de commande, pas
  # depuis le panier ou le catalogue actuel. Le code promo volontairement
  # absent ne peut ainsi jamais être envoyé à GA4.
  def analytics_purchase_event(order)
    {
      transaction_id: order.public_token,
      currency: order.currency,
      value: analytics_euros(order.total_cents),
      shipping: analytics_euros(order.shipping_cents),
      discount: analytics_euros(order.discount_cents),
      items: order.order_items.map do |item|
        {
          item_id: item.sku,
          item_name: item.product_name,
          item_brand: item.brand_name,
          item_variant: item.variant_label,
          price: analytics_euros(item.unit_price_cents),
          quantity: item.quantity
        }
      end
    }
  end

  # Les réponses du questionnaire sont déjà des valeurs contrôlées par le
  # formulaire. Elles restent néanmoins séparées des libellés traduits : GA4
  # reçoit des clés stables et jamais du texte saisi par un visiteur.
  def analytics_quiz_started_event
    { quiz_name: "perfume_finder" }
  end

  def analytics_quiz_completed_event(family:, budget:, results_count:)
    return if family.blank?

    {
      quiz_name: "perfume_finder",
      family: family,
      budget_range: quiz_budget_range(budget),
      results_count: results_count.to_i
    }.compact
  end

  # La recherche libre n'est jamais sérialisée dans le HTML analytique. Les
  # autres valeurs sont résolues côté Rails depuis les objets du catalogue.
  def analytics_catalog_search_event(query:, family:, brand:, model:, audience:, max_price:)
    payload = {
      search_used: query.present?,
      filter_family: family&.slug,
      filter_brand: brand&.slug,
      filter_model: model&.slug,
      filter_audience: audience,
      filter_max_price: CATALOG_PRICE_FILTERS.include?(max_price.to_s) ? max_price.to_s : nil
    }.compact

    filters_count = payload.except(:search_used).size + (payload[:search_used] ? 1 : 0)
    return if filters_count.zero?

    payload.merge(filters_count: filters_count)
  end

  private

  def quiz_budget_range(value)
    value if QUIZ_BUDGET_RANGES.include?(value)
  end

  def analytics_euros(cents)
    cents.to_i / 100.0
  end
end

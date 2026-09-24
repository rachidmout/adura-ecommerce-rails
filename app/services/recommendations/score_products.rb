module Recommendations
  class ScoreProducts
    Result = Data.define(:product, :score, :reasons)

    BUDGET_RANGES = {
      "under_30" => (..2_999),
      "30_40" => (3_000...4_000),
      "40_50" => (4_000...5_000),
      "50_plus" => (5_000..)
    }.freeze

    def initialize(answers:, scope: Product.visible)
      @answers = answers.to_h.symbolize_keys
      @scope = scope.includes(:brand, :perfume_profile, :product_variants, product_olfactory_families: :olfactory_family)
    end

    def call(limit: 3)
      scope.filter_map { |product| score(product) }
        .sort_by { |result| [ -result.score, result.product.name ] }
        .first(limit)
    end

    private

    attr_reader :answers, :scope

    def score(product)
      points = 0
      reasons = []
      family_slug = product.primary_family&.slug

      if answers[:family].present? && family_slug == answers[:family]
        points += 6
        reasons << "sa famille #{product.primary_family.name.downcase}"
      end

      if audience_matches?(product.perfume_profile&.audience)
        points += 3
        reasons << "son univers"
      end

      if budget_selected?
        return nil unless product.product_variants.any? { |variant| variant.available? && budget_range.cover?(variant.price_cents) }

        points += 2
        reasons << "une variante dans votre budget"
      end

      if answers[:occasion].present? && product.perfume_profile&.occasion_codes&.include?(answers[:occasion])
        points += 2
        reasons << "l’occasion recherchée"
      end

      return nil unless product.available? && points.positive?

      Result.new(product: product, score: points, reasons: reasons)
    end

    def audience_matches?(audience)
      answers[:audience].blank? || answers[:audience] == "all" || audience == answers[:audience]
    end

    def budget_selected?
      budget_range.present?
    end

    def budget_range
      BUDGET_RANGES[answers[:budget]]
    end
  end
end

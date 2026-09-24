require "test_helper"

class RecommendationsScoreProductsTest < ActiveSupport::TestCase
  test "uses durable budget ranges with exclusive upper bounds" do
    under_thirty = create_publishable_product(slug: "under-thirty", family_slug: "gourmand", price_cents: 2_999)
    thirty = create_publishable_product(slug: "thirty", family_slug: "gourmand", price_cents: 3_000)
    forty = create_publishable_product(slug: "forty", family_slug: "gourmand", price_cents: 4_000)
    fifty = create_publishable_product(slug: "fifty", family_slug: "gourmand", price_cents: 5_000)

    assert_equal [ under_thirty ], results_for("under_30")
    assert_equal [ thirty ], results_for("30_40")
    assert_equal [ forty ], results_for("40_50")
    assert_equal [ fifty ], results_for("50_plus")
  end

  test "open budget does not filter on price" do
    inexpensive = create_publishable_product(slug: "open-budget-inexpensive", family_slug: "gourmand", price_cents: 1_500)
    premium = create_publishable_product(slug: "open-budget-premium", family_slug: "gourmand", price_cents: 6_000)

    assert_equal [ inexpensive, premium ], results_for("open")
  end

  test "matches a product when one available variant is in the selected range without duplicates" do
    product = create_publishable_product(slug: "multiple-variants", family_slug: "gourmand", price_cents: 6_000)
    product.product_variants.create!(sku: "SKU-MULTIPLE-VARIANTS-30", volume_ml: 50, price_cents: 3_000, stock_quantity: 5, currency: "EUR", active: true)
    product.product_variants.create!(sku: "SKU-MULTIPLE-VARIANTS-35", volume_ml: 10, price_cents: 3_500, stock_quantity: 5, currency: "EUR", active: true)

    assert_equal [ product ], results_for("30_40")
  end

  test "ignores inactive and unavailable variants for budget matching" do
    inactive = create_publishable_product(slug: "inactive-budget-variant", family_slug: "gourmand", price_cents: 6_000)
    inactive.product_variants.create!(sku: "SKU-INACTIVE-BUDGET", volume_ml: 50, price_cents: 3_000, stock_quantity: 5, currency: "EUR", active: false)
    unavailable = create_publishable_product(slug: "unavailable-budget-variant", family_slug: "gourmand", price_cents: 6_000)
    unavailable.product_variants.create!(sku: "SKU-UNAVAILABLE-BUDGET", volume_ml: 50, price_cents: 3_500, stock_quantity: 0, currency: "EUR", active: true)

    assert_empty results_for("30_40")
    assert_equal [ inactive, unavailable ], results_for("50_plus")
  end

  test "combines the budget and olfactory family" do
    matching = create_publishable_product(slug: "gourmand-in-range", family_slug: "gourmand", price_cents: 3_000)
    create_publishable_product(slug: "floral-in-range", family_slug: "floral", price_cents: 3_000)

    assert_equal matching, results_for("30_40").first
  end

  test "translates every budget option in every supported locale" do
    expected_labels = {
      fr: [ "Jusqu’à 30 €", "30–40 €", "40–50 €", "50 € et plus", "Peu importe le prix" ],
      en: [ "Up to €30", "€30–€40", "€40–€50", "€50 and over", "Any price" ],
      es: [ "Hasta 30 €", "30–40 €", "40–50 €", "50 € y más", "Cualquier precio" ],
      de: [ "Bis 30 €", "30–40 €", "40–50 €", "50 € und mehr", "Preis egal" ],
      it: [ "Fino a 30 €", "30–40 €", "40–50 €", "50 € e oltre", "Qualsiasi prezzo" ]
    }

    expected_labels.each do |locale, labels|
      I18n.with_locale(locale) do
        assert_equal labels, %w[budget_under_30 budget_30_40 budget_40_50 budget_50_plus budget_open].map { |key| I18n.t("quiz.show.#{key}") }
      end
    end
  end

  private

  def results_for(budget)
    Recommendations::ScoreProducts.new(answers: { family: "gourmand", audience: "unisex", budget: budget }).call(limit: 10).map(&:product)
  end
end

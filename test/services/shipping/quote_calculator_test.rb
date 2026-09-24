require "test_helper"

class ShippingQuoteCalculatorTest < ActiveSupport::TestCase
  def setup
    @setting = ShopSetting.new(code: "shipping-quote-#{SecureRandom.hex(4)}", base_packaging_weight_grams: 100)
    @zone = ShippingZone.create!(name: "France #{SecureRandom.hex(4)}", active: true)
    @zone.shipping_zone_countries.create!(country_code: "FR")
    @method = @zone.shipping_methods.create!(name: "Standard", carrier_name: "Colissimo", active: true)
  end

  test "uses the per-item logistics weight without adding packaging" do
    variant = weighted_variant(weight: 200)
    rate = create_rate(min: 0, max: 500, price: 690)

    quote = calculate(lines: [ line(variant, 1) ])

    assert_equal 200, quote.package_weight_grams
    assert_equal "FR", quote.country_code
    assert_equal @zone.id, quote.shipping_zone_id
    assert_equal [ rate.id ], quote.methods.map(&:shipping_rate_id)
    assert_equal 690, quote.methods.first.normal_price_cents
    assert_equal 690, quote.methods.first.price_cents
    assert_not quote.methods.first.free_shipping
  end

  test "adds quantities and multiple variant weights" do
    first = weighted_variant(weight: 200, slug: "shipping-first")
    second = weighted_variant(weight: 100, slug: "shipping-second")
    create_rate(min: 0, max: nil, price: 890)

    quote = calculate(lines: [ line(first, 2), line(second, 1) ])

    assert_equal 500, quote.package_weight_grams
  end

  test "uses the complete per-article weight for common volumes and quantities" do
    hundred_ml = weighted_variant(weight: 200, slug: "shipping-100ml")
    fifty_ml = weighted_variant(weight: 100, slug: "shipping-50ml")
    two_hundred_fifty_ml = weighted_variant(weight: 500, slug: "shipping-250ml")
    create_rate(min: 0, max: nil, price: 690)

    assert_equal 200, calculate(lines: [ line(hundred_ml, 1) ]).package_weight_grams
    assert_equal 400, calculate(lines: [ line(hundred_ml, 2) ]).package_weight_grams
    assert_equal 600, calculate(lines: [ line(hundred_ml, 3) ]).package_weight_grams
    assert_equal 500, calculate(lines: [ line(two_hundred_fifty_ml, 1) ]).package_weight_grams
    assert_equal 300, calculate(lines: [ line(hundred_ml, 1), line(fifty_ml, 1) ]).package_weight_grams
  end

  test "supports nil or configured packaging without changing the package weight" do
    variant = weighted_variant(weight: 500, slug: "shipping-no-packaging")
    create_rate(min: 0, max: nil, price: 690)

    assert_equal 500, calculate(lines: [ line(variant, 1) ], setting: ShopSetting.new(code: "no-packaging")).package_weight_grams
    assert_equal 500, calculate(lines: [ line(variant, 1) ], setting: @setting).package_weight_grams
  end

  test "refuses missing variant weight and invalid quantities" do
    missing_weight = weighted_variant(weight: nil, slug: "shipping-no-weight")
    create_rate(min: 0, max: nil, price: 690)

    assert_raises(Shipping::QuoteCalculator::MissingVariantWeight) { calculate(lines: [ line(missing_weight, 1) ]) }
    assert_raises(Shipping::QuoteCalculator::InvalidCartLine) { calculate(lines: [ line(weighted_variant(weight: 100, slug: "shipping-bad-quantity"), 0) ]) }
  end

  test "matches inclusive minimum and maximum bounds and an open final bound" do
    lower = create_rate(min: 0, max: 500, price: 690)
    upper = create_rate(min: 501, max: nil, price: 890)

    assert_equal lower.id, calculate(lines: [ line(weighted_variant(weight: 400, slug: "shipping-at-max"), 1) ]).methods.first.shipping_rate_id
    assert_equal upper.id, calculate(lines: [ line(weighted_variant(weight: 501, slug: "shipping-at-min"), 1) ]).methods.first.shipping_rate_id
    assert_equal upper.id, calculate(lines: [ line(weighted_variant(weight: 2_000, slug: "shipping-open"), 1) ]).methods.first.shipping_rate_id
  end

  test "ignores inactive methods and inactive rates" do
    @method.update!(active: false)
    create_rate(min: 0, max: nil, price: 690)
    assert_raises(Shipping::QuoteCalculator::NoShippingMethodAvailable) { calculate(lines: [ line(weighted_variant(weight: 100, slug: "shipping-inactive-method"), 1) ]) }

    @method.update!(active: true)
    @method.shipping_rates.update_all(active: false)
    assert_raises(Shipping::QuoteCalculator::NoRateForWeight) { calculate(lines: [ line(weighted_variant(weight: 100, slug: "shipping-inactive-rate"), 1) ]) }
  end

  test "rejects inactive and unknown destinations" do
    create_rate(min: 0, max: nil, price: 690)
    @zone.update!(active: false)
    assert_raises(Shipping::QuoteCalculator::DestinationUnsupported) { calculate(lines: [ line(weighted_variant(weight: 100, slug: "shipping-zone-inactive"), 1) ]) }

    assert_raises(Shipping::QuoteCalculator::DestinationUnsupported) { calculate(country_code: "BE", lines: [ line(weighted_variant(weight: 100, slug: "shipping-zone-unknown"), 1) ]) }
  end

  test "returns every eligible active method" do
    first_rate = create_rate(min: 0, max: nil, price: 690)
    express = @zone.shipping_methods.create!(name: "Express", carrier_name: "Chronopost", active: true)
    second_rate = express.shipping_rates.create!(min_weight_grams: 0, price_cents: 1_290, active: true)

    quote = calculate(lines: [ line(weighted_variant(weight: 100, slug: "shipping-multiple-methods"), 1) ])

    assert_equal [ first_rate.id, second_rate.id ].sort, quote.methods.map(&:shipping_rate_id).sort
  end

  test "applies free shipping from the pre-promotion subtotal only" do
    @method.update!(free_shipping_threshold_cents: 5_000)
    create_rate(min: 0, max: nil, price: 690)
    variant = weighted_variant(weight: 100, slug: "shipping-free-threshold")

    assert_equal 690, calculate(lines: [ line(variant, 1) ], subtotal: 4_999).methods.first.price_cents
    exact_threshold = calculate(lines: [ line(variant, 1) ], subtotal: 5_000).methods.first
    above_threshold = calculate(lines: [ line(variant, 1) ], subtotal: 6_000).methods.first

    assert_equal 690, exact_threshold.normal_price_cents
    assert_equal 0, exact_threshold.price_cents
    assert exact_threshold.free_shipping
    assert_equal 0, above_threshold.price_cents
  end

  test "quotes the configured France, Europe and Morocco bands at exact weights" do
    @method.update!(free_shipping_threshold_cents: 5_000)
    [ [ 0, 250, 590 ], [ 251, 500, 790 ], [ 501, 750, 950 ], [ 751, 1_000, 990 ], [ 1_001, 2_000, 1_190 ], [ 2_001, 5_000, 1_790 ] ].each do |min, max, price|
      create_rate(min: min, max: max, price: price)
    end

    europe = configured_zone("Europe", %w[BE LU NL DE ES PT IT], [ [ 0, 500, 1_590 ], [ 501, 1_000, 1_990 ], [ 1_001, 2_000, 2_290 ], [ 2_001, 5_000, 2_990 ] ])
    morocco = configured_zone("Maroc", [ "MA" ], [ [ 0, 500, 2_490 ], [ 501, 1_000, 2_990 ], [ 1_001, 2_000, 3_290 ], [ 2_001, 5_000, 4_090 ] ])

    assert_equal 590, quote_price(country: "FR", weight: 200)
    assert_equal 790, quote_price(country: "FR", weight: 400)
    assert_equal 950, quote_price(country: "FR", weight: 600)
    assert_equal 590, quote_price(country: "FR", weight: 250)
    assert_equal 790, quote_price(country: "FR", weight: 251)
    assert_equal 0, quote_price(country: "FR", weight: 200, subtotal: 5_000)

    assert_equal 1_590, quote_price(country: "BE", weight: 200)
    assert_equal 1_590, quote_price(country: "BE", weight: 400)
    assert_equal 1_990, quote_price(country: "BE", weight: 600)
    assert_equal 1_590, quote_price(country: "BE", weight: 500)
    assert_equal 1_990, quote_price(country: "BE", weight: 501)
    assert_equal 1_590, quote_price(country: "BE", weight: 200, subtotal: 5_000)

    assert_equal 2_490, quote_price(country: "MA", weight: 200)
    assert_equal 2_990, quote_price(country: "MA", weight: 600)
    assert_equal 2_490, quote_price(country: "MA", weight: 500)
    assert_equal 2_990, quote_price(country: "MA", weight: 501)
    assert_equal 2_490, quote_price(country: "MA", weight: 200, subtotal: 5_000)

    assert_equal %w[BE DE ES IT LU NL PT], europe.shipping_zone_countries.order(:country_code).pluck(:country_code)
    assert_equal [ "MA" ], morocco.shipping_zone_countries.pluck(:country_code)
  end

  test "uses future rate changes without changing an existing order snapshot" do
    rate = create_rate(min: 0, max: nil, price: 690)
    variant = weighted_variant(weight: 100, slug: "shipping-future-rate")
    order = create_paid_order(variant: variant)

    before_change = calculate(lines: [ line(variant, 1) ]).methods.first
    rate.update!(price_cents: 890)
    after_change = calculate(lines: [ line(variant, 1) ]).methods.first

    assert_equal 690, before_change.price_cents
    assert_equal 890, after_change.price_cents
    assert_equal 490, order.reload.shipping_cents
  end

  private

  def weighted_variant(weight:, slug: "shipping-variant")
    variant = create_publishable_product(slug: "#{slug}-#{SecureRandom.hex(3)}").product_variants.first
    variant.update!(shipping_weight_grams: weight) if weight
    variant
  end

  def line(variant, quantity)
    Cart::Line.new(variant: variant, quantity: quantity)
  end

  def create_rate(min:, max:, price:)
    @method.shipping_rates.create!(min_weight_grams: min, max_weight_grams: max, price_cents: price, active: true)
  end

  def configured_zone(name, country_codes, bands)
    zone = ShippingZone.create!(name: "#{name} #{SecureRandom.hex(4)}", active: true)
    country_codes.each { |country_code| zone.shipping_zone_countries.create!(country_code: country_code) }
    method = zone.shipping_methods.create!(name: "Standard", carrier_name: "Colissimo", active: true)
    bands.each do |min, max, price|
      method.shipping_rates.create!(min_weight_grams: min, max_weight_grams: max, price_cents: price, active: true)
    end
    zone
  end

  def quote_price(country:, weight:, subtotal: 2_000)
    variant = weighted_variant(weight: weight, slug: "shipping-rate-#{country}-#{weight}-#{subtotal}")
    calculate(country_code: country, lines: [ line(variant, 1) ], subtotal: subtotal).methods.first.price_cents
  end

  def calculate(country_code: "FR", lines:, subtotal: 2_000, setting: @setting)
    Shipping::QuoteCalculator.new(country_code: country_code, lines: lines, subtotal_cents: subtotal, shop_setting: setting).call
  end
end

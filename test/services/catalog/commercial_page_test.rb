require "test_helper"

class Catalog::CommercialPageTest < ActiveSupport::TestCase
  test "gourmands page selects only in-stock products from the gourmand family" do
    gourmand = create_publishable_product(slug: "commercial-gourmand", family_slug: "gourmand")
    fruity = create_publishable_product(slug: "commercial-fruity", family_slug: "fruite")
    sold_out = create_publishable_product(slug: "commercial-gourmand-sold-out", family_slug: "gourmand", stock_quantity: 0)

    products = Catalog::CommercialPage.find("gourmands").products

    assert_includes products, gourmand
    assert_not_includes products, fruity
    assert_not_includes products, sold_out
  end

  test "Lattafa page includes Lattafa Pride and excludes other brands" do
    lattafa = create_publishable_product(slug: "commercial-lattafa")
    pride = create_publishable_product(slug: "commercial-lattafa-pride")
    other = create_publishable_product(slug: "commercial-other-brand")
    lattafa.update!(brand: Brand.find_or_create_by!(slug: "lattafa") { |brand| brand.name = "Lattafa" })
    pride.update!(brand: Brand.find_or_create_by!(slug: "lattafa-pride") { |brand| brand.name = "Lattafa Pride" })

    products = Catalog::CommercialPage.find("lattafa").products

    assert_includes products, lattafa
    assert_includes products, pride
    assert_not_includes products, other
  end

  test "Dubai page uses only its explicitly configured available brands" do
    selected = create_publishable_product(slug: "commercial-dubai-lattafa")
    excluded = create_publishable_product(slug: "commercial-dubai-other")
    selected.update!(brand: Brand.find_or_create_by!(slug: "gulf-orchid") { |brand| brand.name = "Gulf Orchid" })

    products = Catalog::CommercialPage.find("dubai").products

    assert_includes products, selected
    assert_not_includes products, excluded
  end

  test "unknown commercial page is not resolved" do
    assert_nil Catalog::CommercialPage.find("unknown")
  end
end

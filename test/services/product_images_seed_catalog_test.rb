require "test_helper"

class ProductImagesSeedCatalogTest < ActiveSupport::TestCase
  test "loads the real catalog from db/seeds.rb without touching the database" do
    assert_no_difference [ "Product.count", "ProductVariant.count", "ProductImage.count", "Order.count" ] do
      @catalog = ProductImages::SeedCatalog.load
    end

    assert_equal 41, @catalog.size
    assert @catalog.all? { |data| data[:slug].present? && data[:images].present? }
    assert_includes @catalog.map { |data| data[:slug] }, "yara-lattafa"
  end

  test "raises a clear error when the file has no catalog array" do
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("empty_seeds.rb")
      path.write("puts 'no catalog here'\n")

      error = assert_raises(ProductImages::SeedCatalog::ParseError) { ProductImages::SeedCatalog.load(path: path) }
      assert_match(/catalog introuvable/, error.message)
    end
  end

  test "rejects executable Ruby in the catalog without executing it" do
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("executable_seeds.rb")
      path.write('catalog = [ { slug: ENV.fetch("MALICIOUS_VALUE"), images: [] } ]')

      error = assert_raises(ProductImages::SeedCatalog::ParseError) { ProductImages::SeedCatalog.load(path: path) }

      assert_match(/valeur non autorisée/, error.message)
    end
  end
end

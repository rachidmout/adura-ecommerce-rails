require "test_helper"

class ProductImageTest < ActiveSupport::TestCase
  test "generated alternative text follows the current locale without changing manual text" do
    product = create_publishable_product(slug: "localized-image-alt")
    image = product.product_images.build(alt_text: product.name, primary: true)

    I18n.with_locale(:en) do
      assert_match "fragrance presentation", image.alt_text
    end

    I18n.with_locale(:es) do
      assert_match "presentación del perfume", image.alt_text
    end

    I18n.with_locale(:nl) do
      assert_match "presentatie van het parfum", image.alt_text
    end

    image.alt_text = "Manual product photograph"
    I18n.with_locale(:de) do
      assert_equal "Manual product photograph", image.alt_text
    end
  end

  test "legacy seed alternative text is localized without changing a manual alternative text" do
    product = create_publishable_product(slug: "legacy-localized-image-alt")
    image = product.primary_image
    image.update!(alt_text: "#{product.name} de #{product.brand.name} · #{product.product_variants.first.label}")

    I18n.with_locale(:en) do
      assert_match "fragrance presentation", image.alt_text
    end

    I18n.with_locale(:de) do
      assert_match "Duftpräsentation", image.alt_text
    end

    image.update!(alt_text: "Handwritten catalogue image")
    I18n.with_locale(:nl) do
      assert_equal "Handwritten catalogue image", image.alt_text
    end
  end
end

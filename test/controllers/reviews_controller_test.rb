require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  test "creates a pending review that is not yet publicly visible" do
    product = create_publishable_product(slug: "public-review-create-test")

    assert_difference "Review.count", 1 do
      post product_reviews_path(product_slug: product.slug, locale: nil), params: {
        review: { author_name: "Client", author_email: "client@example.com", rating: 5, comment: "Très satisfait de cet achat." }
      }
    end

    review = Review.last
    assert review.pending?
  end

  test "a filled honeypot field silently drops the submission" do
    product = create_publishable_product(slug: "public-review-honeypot-test")

    assert_no_difference "Review.count" do
      post product_reviews_path(product_slug: product.slug, locale: nil), params: {
        review: { author_name: "Bot", author_email: "bot@example.com", rating: 5, comment: "Spam", nickname: "filled-by-a-bot" }
      }
    end
  end

  test "successful review feedback follows the Dutch public locale" do
    product = create_publishable_product(slug: "dutch-public-review")

    post product_reviews_path(product_slug: product.slug, locale: :nl), params: {
      review: { author_name: "Klant", author_email: "klant@example.com", rating: 5, comment: "Een fijne geur voor elke dag." }
    }

    assert_redirected_to product_path(product.slug, locale: :nl)
    assert_equal I18n.t("products.show.reviews_success", locale: :nl), flash[:notice]
  end

  test "invalid Dutch review feedback does not fall back to French or a missing translation" do
    product = create_publishable_product(slug: "invalid-dutch-public-review")

    post product_reviews_path(product_slug: product.slug, locale: :nl), params: {
      review: { author_name: "", author_email: "ongeldig", rating: 0, comment: "" }
    }

    assert_match(/Naam moet ingevuld zijn/, flash[:alert])
    assert_match(/Beoordeling moet tussen 1 en 5 liggen/, flash[:alert])
    assert_no_match(/Translation missing|doit être/, flash[:alert])
  end
end

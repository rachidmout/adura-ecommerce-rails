require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  test "rejects a rating outside 1..5" do
    product = create_publishable_product(slug: "review-rating-test")
    review = Review.new(product: product, author_name: "Client", author_email: "client@example.com", rating: 6, comment: "Trop haut")

    assert_not review.valid?
    assert_includes review.errors[:rating], "doit être comprise entre 1 et 5"
  end

  test "a pending review is excluded from the approved scope used on the public product page" do
    product = create_publishable_product(slug: "review-visibility-test")
    pending = product.reviews.create!(author_name: "Client", author_email: "pending@example.com", rating: 4, comment: "En attente")

    assert_not_includes product.reviews.approved, pending
    assert_equal 0, product.reviews_count
  end

  test "an approved review is included in the approved scope and counts toward the average" do
    product = create_publishable_product(slug: "review-approved-test")
    product.reviews.create!(author_name: "A", author_email: "a@example.com", rating: 4, comment: "Bien", status: :approved)
    product.reviews.create!(author_name: "B", author_email: "b@example.com", rating: 2, comment: "Moyen", status: :approved)
    product.reviews.create!(author_name: "C", author_email: "c@example.com", rating: 5, comment: "En attente") # pending, must not count

    assert_equal 2, product.reviews_count
    assert_equal 3.0, product.average_rating.to_f
  end

  test "verified_purchase is true when the author bought the product in a completed order" do
    product = create_publishable_product(slug: "review-verified-test")
    variant = product.product_variants.first
    order = create_paid_order(variant: variant, status: :paid)

    review = product.reviews.create!(author_name: "Buyer", author_email: order.email, rating: 5, comment: "Authentique achat")

    assert review.verified_purchase?
  end

  test "verified_purchase is false when there is no matching completed order" do
    product = create_publishable_product(slug: "review-unverified-test")

    review = product.reviews.create!(author_name: "Stranger", author_email: "never-bought@example.com", rating: 5, comment: "Avis sans achat")

    assert_not review.verified_purchase?
  end
end

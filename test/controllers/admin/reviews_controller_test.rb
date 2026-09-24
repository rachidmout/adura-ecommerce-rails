require "test_helper"

module Admin
  class ReviewsControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_reviews_path
      assert_redirected_to admin_login_path
    end

    test "approve makes a pending review visible on the public product page" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(slug: "admin-review-approve-test")
      review = product.reviews.create!(author_name: "Client", author_email: "client@example.com", rating: 4, comment: "Bien")

      patch approve_admin_review_path(review)

      assert_redirected_to admin_reviews_path
      assert review.reload.approved?
    end

    test "hide removes a review from the public product page" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(slug: "admin-review-hide-test")
      review = product.reviews.create!(author_name: "Client", author_email: "client@example.com", rating: 4, comment: "Bien", status: :approved)

      patch hide_admin_review_path(review)

      assert review.reload.hidden?
      assert_not_includes product.reviews.approved, review
    end

    test "destroy permanently deletes a review" do
      sign_in_as(create_admin_user)
      product = create_publishable_product(slug: "admin-review-destroy-test")
      review = product.reviews.create!(author_name: "Client", author_email: "client@example.com", rating: 4, comment: "Bien")

      assert_difference "Review.count", -1 do
        delete admin_review_path(review)
      end
    end
  end
end

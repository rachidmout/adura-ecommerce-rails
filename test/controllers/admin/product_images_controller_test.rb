require "test_helper"

module Admin
  class ProductImagesControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      product = create_publishable_product
      post admin_product_images_path(product), params: { images: [ fixture_file_upload("bottle.jpg", "image/jpeg") ] }
      assert_redirected_to admin_login_path
    end

    test "create attaches an uploaded image to the product" do
      sign_in_as(create_admin_user)
      product = create_publishable_product

      assert_difference "product.product_images.count", 1 do
        post admin_product_images_path(product), params: { images: [ fixture_file_upload("bottle.jpg", "image/jpeg") ] }
      end
      assert_redirected_to edit_admin_product_path(product)
    end

    test "the upload form offers a local image preview before submission" do
      sign_in_as(create_admin_user)
      product = create_publishable_product

      get edit_admin_product_path(product)

      assert_select "form[data-controller='image-preview']"
      assert_select "input[type='file'][data-image-preview-target='input'][data-action='change->image-preview#preview']"
      assert_select "[data-image-preview-target='preview'][hidden]"
    end

    test "the image gallery keeps the alternative text form and image actions available" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      image = product.primary_image

      get edit_admin_product_path(product)

      assert_response :success
      assert_select ".admin-gallery"
      assert_select ".admin-gallery-item", count: 1
      assert_select "form.admin-gallery-alt-form[action=?]", admin_product_image_path(product, image)
      assert_select "input#image_alt_text_#{image.id}[name='image[alt_text]']"
      assert_select ".admin-gallery-alt-form input[type='submit'][value='Enregistrer']"
      assert_select ".admin-gallery-controls form[action=?]", move_up_admin_product_image_path(product, image)
      assert_select ".admin-gallery-controls form[action=?]", move_down_admin_product_image_path(product, image)
      assert_select ".admin-gallery-controls form[action=?]", admin_product_image_path(product, image)
    end

    test "destroy removes the image and promotes another one to primary" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      second = product.product_images.create!(alt_text: "Deuxième photo", position: 1)
      second.file.attach(io: File.open(file_fixture("bottle.jpg")), filename: "bottle.jpg", content_type: "image/jpeg")
      primary = product.product_images.find(&:primary?)

      delete admin_product_image_path(product, primary)

      assert_redirected_to edit_admin_product_path(product)
      assert_not ProductImage.exists?(primary.id)
      assert second.reload.primary?
    end

    test "set_primary switches which image is primary" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      second = product.product_images.create!(alt_text: "Deuxième photo", position: 1)
      second.file.attach(io: File.open(file_fixture("bottle.jpg")), filename: "bottle.jpg", content_type: "image/jpeg")

      patch set_primary_admin_product_image_path(product, second)

      assert second.reload.primary?
      assert_equal 1, product.product_images.where(primary: true).count
    end

    test "move_up and move_down swap positions with the neighbouring image" do
      sign_in_as(create_admin_user)
      product = create_publishable_product
      first = product.product_images.find(&:primary?)
      second = product.product_images.create!(alt_text: "Deuxième photo", position: 1)
      second.file.attach(io: File.open(file_fixture("bottle.jpg")), filename: "bottle.jpg", content_type: "image/jpeg")

      patch move_down_admin_product_image_path(product, first)

      assert_operator first.reload.position, :>, second.reload.position
    end
  end
end

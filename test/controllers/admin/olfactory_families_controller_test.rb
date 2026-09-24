require "test_helper"

module Admin
  class OlfactoryFamiliesControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_olfactory_families_path
      assert_redirected_to admin_login_path
    end

    test "updates the editorial and SEO fields of a family" do
      sign_in_as(create_admin_user)
      family = OlfactoryFamily.find_or_create_by!(slug: "gourmand") { |record| record.name = "Gourmand" }

      patch admin_olfactory_family_path(family), params: { olfactory_family: { meta_title: "Parfums gourmands · ADURA", meta_description: "Notre sélection." } }

      assert_redirected_to admin_olfactory_families_path
      assert_equal "Parfums gourmands · ADURA", family.reload.meta_title
    end

    test "shows the active localized SEO values when a family has no admin override" do
      sign_in_as(create_admin_user)
      family = OlfactoryFamily.find_or_create_by!(slug: "gourmand") { |record| record.name = "Gourmand" }
      family.update!(meta_title: nil, meta_description: nil)

      get admin_olfactory_families_path

      assert_response :success
      assert_includes response.body, "Parfums gourmands vanille, caramel et pistache | ADURA"
      assert_includes response.body, "Découvrez les parfums gourmands sélectionnés par ADURA"
      assert_select "small.muted", text: "Valeur active I18n", count: 2
    end
  end
end

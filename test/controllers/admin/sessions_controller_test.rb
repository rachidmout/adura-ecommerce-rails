require "test_helper"

module Admin
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    test "signs in with valid credentials and redirects to the dashboard" do
      admin = create_admin_user
      sign_in_as(admin)

      assert_redirected_to admin_root_path
      follow_redirect!
      assert_select "h1", /Tableau de bord/
    end

    test "rejects an incorrect password" do
      admin = create_admin_user
      post admin_login_path, params: { email: admin.email, password: "wrong-password" }

      assert_response :unprocessable_entity
    end

    test "rejects a deactivated admin" do
      admin = create_admin_user
      admin.update!(active: false)
      sign_in_as(admin)

      assert_response :unprocessable_entity
    end

    test "logout clears the session and blocks further admin access" do
      admin = create_admin_user
      sign_in_as(admin)
      delete admin_logout_path

      get admin_root_path
      assert_redirected_to admin_login_path
    end
  end
end

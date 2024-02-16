require "test_helper"

class Accounts::LogosControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show stock" do
    get account_logo_url
    assert_equal @response.headers["content-type"], "image/png"
  end

  test "show custom" do
    accounts(:signal).update! logo: fixture_file_upload("moon.jpg", "image/jpeg")

    get account_logo_url
    assert_equal @response.headers["content-type"], "image/png"
  end

  test "destroy" do
    accounts(:signal).update! logo: fixture_file_upload("moon.jpg", "image/jpeg")

    delete account_logo_url
    assert_redirected_to edit_account_url
    assert_not accounts(:signal).reload.logo.attached?
  end
end

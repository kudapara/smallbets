require "test_helper"

class Users::AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show initials" do
    get user_avatar_url(users(:kevin))
    assert_select "text", text: "K"
  end
end

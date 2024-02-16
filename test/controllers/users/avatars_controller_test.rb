require "test_helper"

class Users::AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show initials" do
    get user_avatar_url(users(:kevin))
    assert_select "text", text: "K"
  end

  test "show image" do
    users(:kevin).update! avatar: fixture_file_upload("moon.jpg", "image/jpeg")
    get user_avatar_url(users(:kevin))
    assert_equal "image/webp", @response.content_type
  end
end

require "test_helper"

class Messages::ByBotsControlleTest < ActionDispatch::IntegrationTest
  setup do
    @room = rooms(:watercooler)
  end

  test "create" do
    assert_difference -> { Message.count }, +1 do
      post room_bot_messages_url(@room, users(:bender).bot_key), params: "Hello Bot World!"
      assert_equal "Hello Bot World!", Message.last.plain_text_body
    end
  end

  test "create with UTF-8 content" do
    assert_difference -> { Message.count }, +1 do
      post room_bot_messages_url(@room, users(:bender).bot_key), params: "Hello 👋!"
      assert_equal "Hello 👋!", Message.last.plain_text_body
    end
  end

  test "create file" do
    assert_difference -> { Message.count }, +1 do
      post room_bot_messages_url(@room, users(:bender).bot_key), params: { attachment: fixture_file_upload("moon.jpg", "image/jpeg") }
      assert Message.last.attachment.present?
    end
  end

  test "denied index" do
    get room_messages_url(@room, bot_key: users(:bender).bot_key, format: :json)
    assert_response :forbidden
  end
end

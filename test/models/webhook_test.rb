require "test_helper"

class WebhookTest < ActiveSupport::TestCase
  test "delivery" do
    WebMock.stub_request(:post, webhooks(:mentions).url).to_return(status: 200, body: "", headers: {})
    response = webhooks(:mentions).deliver_now(messages(:first), :created)
    assert_equal 200, response.code.to_i
  end

  test "delivery with OK text reply" do
    WebMock.stub_request(:post, webhooks(:mentions).url).to_return(status: 200, body: "Hello back!", headers: { "Content-Type" => "text/plain" })
    response = webhooks(:mentions).deliver_now(messages(:first), :created)

    reply_message = Message.last
    assert_equal "Hello back!", reply_message.body.to_plain_text
  end

  test "delivery with OK attachment reply" do
    WebMock.stub_request(:post, webhooks(:mentions).url).to_return(status: 200, body: file_fixture("moon.jpg"), headers: { "Content-Type" => "image/jpeg" })
    response = webhooks(:mentions).deliver_now(messages(:first), :created)

    reply_message = Message.last
    assert reply_message.attachment.present?
  end

  test "delivery with error reply" do
    assert_no_difference -> { Message.count } do
      WebMock.stub_request(:post, webhooks(:mentions).url).to_return(status: 500, body: "Internal Error!", headers: {})
      response = webhooks(:mentions).deliver_now(messages(:first), :created)
    end
  end

  test "delivery that times out" do
    Webhook.any_instance.stubs(:post).raises(Net::OpenTimeout)
    response = webhooks(:mentions).deliver_now(messages(:first), :created)

    reply_message = Message.last
    assert_equal "Failed to respond within 300 seconds", reply_message.body.to_plain_text
  end
  
  test "delivery of non-mention" do
    assert_difference -> { Message.count }, 0 do
      WebMock.stub_request(:post, webhooks(:everything).url).to_return(status: 200, body: "Accidental text in response", headers: { "Content-Type" => "text/plain" })
      response = webhooks(:everything).deliver_now(messages(:first), :deleted)
      assert_equal 200, response.code.to_i
    end
  end
end

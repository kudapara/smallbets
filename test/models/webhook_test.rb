require "test_helper"

class WebhookTest < ActiveSupport::TestCase
  test "delivery" do
    WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 200, body: "", headers: {})
    response = webhooks(:bender).deliver(messages(:first))
    assert_equal 200, response.code.to_i
  end

  test "delivery with OK text reply" do
    WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 200, body: "Hello back!", headers: { "Content-Type" => "text/plain" })
    response = webhooks(:bender).deliver(messages(:first))

    reply_message = Message.last
    assert_equal "Hello back!", reply_message.body.to_plain_text
  end

  test "delivery with OK attachment reply" do
    WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 200, body: file_fixture("moon.jpg"), headers: { "Content-Type" => "image/jpeg" })
    response = webhooks(:bender).deliver(messages(:first))

    reply_message = Message.last
    assert reply_message.attachment.present?
  end

  test "delivery with error reply" do
    assert_no_difference -> { Message.count } do
      WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 500, body: "Internal Error!", headers: {})
      response = webhooks(:bender).deliver(messages(:first))
    end
  end

  test "delivery that times out" do
    Webhook.any_instance.stubs(:post).raises(Net::OpenTimeout)
    response = webhooks(:bender).deliver(messages(:first))

    reply_message = Message.last
    assert_equal "Failed to respond within 300 seconds", reply_message.body.to_plain_text
  end
end

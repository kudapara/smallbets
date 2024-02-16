require "test_helper"
require "restricted_http/private_network_guard"

class Opengraph::FetchTest < ActiveSupport::TestCase
  setup do
    @fetch = Opengraph::Fetch.new
    @url = URI.parse("https://www.example.com")
  end

  test "#fetch fetches valid HTML" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 200, body: "<body>ok<body>", headers: { content_type: "text/html" })

    assert_equal "<body>ok<body>", @fetch.fetch(@url)
  end

  test "#fetch discards other content types" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 200, body: "I'm not HTML!", headers: { content_type: "text/plain" })

    assert_nil @fetch.fetch(@url)
  end

  test "#fetch follows redirects" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 302, headers: { location: "https://www.other.com/" })

    WebMock.stub_request(:get, "https://www.other.com/")
      .to_return(status: 200, body: "<body>ok<body>", headers: { content_type: "text/html" })

    assert_equal "<body>ok<body>", @fetch.fetch(@url)
  end

  test "#fetch does not follow redirects to private networks" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 302, headers: { location: "https://www.other.com/" })

    WebMock.stub_request(:get, "https://www.other.com/")
      .to_return(status: 200, body: "<body>ok<body>", headers: { content_type: "text/html" })

    RestrictedHTTP::PrivateNetworkGuard.stubs(:resolvable_public_ip?).with("https://www.other.com/").returns(false)

    assert_raises Opengraph::Fetch::RedirectDeniedError do
      @fetch.fetch(@url)
    end
  end

  test "#fetch is empty following redirects that never finish" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 302, headers: { location: "https://www.example.com/" })

    assert_raises Opengraph::Fetch::TooManyRedirectsError do
      @fetch.fetch(@url)
    end
  end

  test "#fetch ignores large responses" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 200, body: "too large", headers: { content_length: 1.gigabyte, content_type: "text/html" })

    assert_nil @fetch.fetch(@url)
  end

  test "#fetch ignores large responses that were missing their content length" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 200, body: large_body_content, headers: { content_type: "text/html" })

    assert_nil @fetch.fetch(@url)
  end

  test "#fetch ignores large responses that were lying about their content length" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 200, body: large_body_content, headers: { content_length: 1.megabyte, content_type: "text/html" })

    assert_nil @fetch.fetch(@url)
  end

  private
    def large_body_content
      "x" * (Opengraph::Fetch::MAX_BODY_SIZE + 1)
    end
end

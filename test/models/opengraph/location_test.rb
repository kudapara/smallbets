require "test_helper"
require "restricted_http/private_network_guard"

class Opengraph::LocationTest < ActiveSupport::TestCase
  test "url validations" do
    assert Opengraph::Location.new("https://www.example.com").valid?
    assert Opengraph::Location.new("http://www.example.com").valid?

    assert_not Opengraph::Location.new("~/etc/password").valid?
    assert_not Opengraph::Location.new("ftp://speedtest.tele2.net").valid?
    assert_not Opengraph::Location.new("httpfake").valid?
    assert_not Opengraph::Location.new(" foo").valid?
    assert_not Opengraph::Location.new("https/incorrect").valid?
  end

  test "private network urls" do
    Resolv.stubs(:getaddress).with("www.example.com").returns("172.16.0.0")

    location = Opengraph::Location.new("https://www.example.com")
    assert_not location.valid?
    assert_equal [ "is not public" ], location.errors[:url]
  end

  test "validations while reading file urls" do
    large_file = Opengraph::Location.new("https://www.example.com/100gb.zip")
    assert_not large_file.valid?(:read)
    assert_equal [ "is not for a webpage" ], large_file.errors[:url]

    assert_not Opengraph::Location.new("http://www.example.com/video.mp4").valid?(:read)
    assert_not Opengraph::Location.new("http://www.example.com/archive.tar").valid?(:read)

    assert_not Opengraph::Location.new("https://www.example.com/large.heic").valid?(:read)
    assert_not Opengraph::Location.new("https://www.example.com/image.jpeg").valid?(:read)
    assert_not Opengraph::Location.new("https://www.example.com/malware.exe").valid?(:read)
    assert_not Opengraph::Location.new("https://www.example.com/massiveOS.iso").valid?(:read)
  end

  test "read valid HTML" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 200, body: "<body>ok<body>", headers: { content_type: "text/html" })

    location = Opengraph::Location.new("https://www.example.com")
    assert_equal "<body>ok<body>", location.read
  end

  test "read ignores invalid responses" do
    WebMock.stub_request(:get, "https://www.example.com/")
      .to_return(status: 200, body: "too large", headers: { content_length: 1.gigabyte, content_type: "text/html" })

    location = Opengraph::Location.new("https://www.example.com")
    assert_nil location.read
  end
end

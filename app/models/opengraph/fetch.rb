require "net/http"
require "restricted_http/private_network_guard"

class Opengraph::Fetch
  ALLOWED_CONTENT_TYPE = "text/html"
  MAX_BODY_SIZE = 5.megabytes
  MAX_REDIRECTS = 10

  class TooManyRedirectsError < StandardError; end
  class RedirectDeniedError < StandardError; end

  def fetch(url)
    MAX_REDIRECTS.times do
      Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == "https") do |http|
        http.request Net::HTTP::Get.new(url) do |response|
          if response.is_a?(Net::HTTPRedirection)
            url = follow_redirect(response)
          else
            return body_if_acceptable(response)
          end
        end
      end
    end

    raise TooManyRedirectsError
  end

  private
    def follow_redirect(response)
      URI.parse(response["location"]).tap do |url|
        raise RedirectDeniedError unless url.is_a?(URI::HTTP) && RestrictedHTTP::PrivateNetworkGuard.resolvable_public_ip?(url.to_s)
      end
    end

    def body_if_acceptable(response)
      size_restricted_body(response) if response_valid?(response)
    end

    def size_restricted_body(response)
      # We've already checked the Content-Length header, to try to avoid reading
      # the body of any large responses. But that header could be wrong or
      # missing. To be on the safe side, we'll read the body in chunks, and bail
      # if it runs over our size limit.
      "".tap do |body|
        response.read_body do |chunk|
          return nil if body.bytesize + chunk.bytesize > MAX_BODY_SIZE
          body << chunk
        end
      end
    end

    def response_valid?(response)
      status_valid?(response) && content_type_valid?(response) && content_length_valid?(response)
    end

    def status_valid?(response)
      response.is_a?(Net::HTTPOK)
    end

    def content_type_valid?(response)
      response.content_type == ALLOWED_CONTENT_TYPE
    end

    def content_length_valid?(response)
      response.content_length.to_i <= MAX_BODY_SIZE
    end
end

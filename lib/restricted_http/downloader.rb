require "restricted_http/client"

module RestrictedHTTP
  class Downloader
    class Error < StandardError; end
    class HostUnresolvable < Downloader::Error; end
    class InvalidUrl < Downloader::Error; end

    class << self
      def get(url, &block)
        handle_response get_url(url), &block
      rescue Resolv::ResolvError
        raise HostUnresolvable, url
      end

      private
        def get_url(url)
          validate_url(url)
          Client.get(url, raw_response: true, open_timeout: 5, timeout: 30)
        end

        def handle_response(response, &block)
          file = response.file
          file.open
          file.binmode

          Tempfile.create("decoded-response") do |decoded|
            decoded.binmode
            decoded.write RestClient::Request.decode(response.headers[:content_encoding], file.read)
            decoded.rewind
            if block_given?
              yield response.code, response.headers, decoded
            else
              [ response.code, response.headers, decoded.read ]
            end
          end
        ensure
          file.try(:unlink)
        end

        def validate_url(url)
          Addressable::URI.parse(url).tap do |uri|
            unless uri.scheme.starts_with?("http")
              raise InvalidUrl, url
            end
          end
        rescue Addressable::URI::InvalidURIError
          raise InvalidUrl, url
        end
    end
  end
end

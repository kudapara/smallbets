require "restclient"
require "restricted_http/private_network_guard"

module RestrictedHTTP
  module Client
    extend self

    %i[ get post patch put delete head options ].each do |verb|
      define_method(verb) do |url, options = {}, &block|
        request_options = request_options_from(verb, url, options)
        begin
          Response.new RestClient::Request.execute(request_options, &block)
        rescue RestClient::Exception => e
          raise unless e.response
          Response.new e.response
        end
      end
    end

    class Response
      delegate_missing_to :@response

      def initialize(response)
        @response = response
      end

      def message
        @response.net_http_res.message
      end

      def capitalized_headers
        headers = {}
        @response.net_http_res.header.each_capitalized do |name, value|
          headers[name] = value
        end
        headers
      end
    end

    private
      def request_options_from(verb, url, options = {})
        options.dup.tap do |req_options|
          req_options[:method] = verb
          req_options[:url] = url

          if req_options.key?(:follow_redirects) && !req_options.delete(:follow_redirects)
            req_options[:max_redirects] = 0
          end

          if body = req_options.delete(:body)
            req_options[:payload] = body
          end

          req_options[:before_execution_proc] ||= enforce_public_ip_proc
        end
      end

      def enforce_public_ip_proc
        Proc.new do |req, _|
          PrivateNetworkGuard.enforce_public_ip(req.uri.to_s)
        end
      end
  end
end

require "resolv"

module RestrictedHTTP
  class Violation < StandardError; end

  module PrivateNetworkGuard
    extend self

    def enforce_public_ip(url)
      if private_ip?(url)
        raise Violation.new("Attempt to access private IP #{url}")
      end
    end

    def resolvable_public_ip?(url)
      !private_ip?(url)
    rescue Resolv::ResolvError
      false
    end

    private
      LOCAL_IP = IPAddr.new("0.0.0.0/8") # "This" network

      def private_ip?(url)
        ip = IPAddr.new(Resolv.getaddress(URI.parse(url).host))
        ip.private? || ip.loopback? || LOCAL_IP.include?(ip)
      rescue URI::InvalidURIError, IPAddr::InvalidAddressError, ArgumentError
        true
      end
  end
end

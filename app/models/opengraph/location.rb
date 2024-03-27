require "restricted_http/private_network_guard"

class Opengraph::Location
  include ActiveModel::Validations

  attr_accessor :url, :parsed_url

  validate :validate_url, :validate_url_is_public
  validate :validate_url_is_for_a_web_page, on: :read

  def initialize(url)
    @url = url
  end

  def read
    fetch_html if valid?
  end

  def resolved_ip
    return @resolved_ip if defined? @resolved_ip
    @resolved_ip = RestrictedHTTP::PrivateNetworkGuard.resolve(parsed_url.host) rescue nil
  end

  private
    def validate_url
      errors.add :url, "is invalid" unless parsed_url.is_a?(URI::HTTP)
    end

    def validate_url_is_public
      errors.add :url, "is not public" unless resolved_ip
    end

    def validate_url_is_for_a_web_page
      errors.add :url, "is not for a webpage" if url.match(FILES_AND_MEDIA_URL_REGEX)
    end

    FILES_AND_MEDIA_URL_REGEX = /\bhttps?:\/\/\S+\.(?:zip|tar|tar\.gz|tar\.bz2|tar\.xz|gz|bz2|rar|7z|dmg|exe|msi|pkg|deb|iso|jpg|jpeg|png|gif|bmp|mp4|mov|avi|mkv|wmv|flv|heic|heif|mp3|wav|ogg|aac|wma|webm|ogv|mpg|mpeg)\b/

    def parsed_url
      return @parsed_url if defined? @parsed_url
      @parsed_url = URI.parse(url) rescue nil
    end

    def fetch_html
      Opengraph::Fetch.new.fetch(parsed_url, ip: resolved_ip)
    rescue => e
      Rails.logger.warn "Failed to fetch #{parsed_url} at #{resolved_ip} (#{e})"
      nil
    end
end

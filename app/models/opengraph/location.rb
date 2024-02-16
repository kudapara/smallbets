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
    fetch_html(parsed_url) if valid?
  end

  private
    def validate_url
      errors.add :url, "is invalid" if parsed_url.blank? || !parsed_url.is_a?(URI::HTTP)
    end

    def validate_url_is_public
      errors.add :url, "is not public" unless RestrictedHTTP::PrivateNetworkGuard.resolvable_public_ip?(url)
    end

    def validate_url_is_for_a_web_page
      errors.add :url, "is not for a webpage" if url.match(FILES_AND_MEDIA_URL_REGEX)
    end

    FILES_AND_MEDIA_URL_REGEX = /\bhttps?:\/\/\S+\.(?:zip|tar|tar\.gz|tar\.bz2|tar\.xz|gz|bz2|rar|7z|dmg|exe|msi|pkg|deb|iso|jpg|jpeg|png|gif|bmp|mp4|mov|avi|mkv|wmv|flv|heic|heif|mp3|wav|ogg|aac|wma|webm|ogv|mpg|mpeg)\b/

    def parsed_url
      @parsed_url ||= begin
        URI.parse(url)
      rescue URI::InvalidURIError
        nil
      end
    end

    def fetch_html(url)
      Opengraph::Fetch.new.fetch(url)
    rescue StandardError => e
      Rails.logger.warn "Failed to fetch #{url} (#{e})"
      nil
    end
end

require 'net/http'
require 'uri'
require 'json'

class Sso::Fetch
  ENDPOINT = "https://smallbets.com/api/userInfo"

  def initialize(token:)
    @token = token
  end
  
  def fetch(open_timeout: 10, read_timeout: 10)
    uri = URI("#{ENDPOINT}/#{@token}")
    response = Net::HTTP.start(uri.host, uri.port, 
                               use_ssl: uri.scheme == 'https',
                               open_timeout: open_timeout, 
                               read_timeout: read_timeout) do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      transform_keys(JSON.parse(response.body))
    else
      Rails.logger.error "Failed to fetch SSO data: #{response.code} - #{response.message}: #{response.body}"
      {}
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "Timed out when fetching SSO data: #{e.message}\n#{e.backtrace.join("\n")}"
    {}
  rescue Exception => e
    Rails.logger.error "Unexpected error when fetching SSO data: #{e.message}\n#{e.backtrace.join("\n")}"
    {}
  end
  
  private
    def transform_keys(response)
      response.symbolize_keys
              .slice(:name, :email, :joinDate, :userId, :twitter, :linkedIn, :personalUrl, :profilePic, :tokenExpiry)
              .tap { |h| h.delete(:name) if h[:name].blank? }
              .transform_keys({
                email: :email_address,
                joinDate: :membership_started_at,
                userId: :sso_user_id,
                twitter: :twitter_username,
                linkedIn: :linkedin_username,
                personalUrl: :personal_url,
                tokenExpiry: :sso_token_expires_at,
                profilePic: :avatar_url
              }).merge(sso_token: @token)
    end
end

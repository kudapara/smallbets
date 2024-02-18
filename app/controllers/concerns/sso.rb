module Sso
  extend ActiveSupport::Concern
  SSO_REFRESH_DELAY = 5.seconds

  included do
    before_action :refresh_user_from_sso, if: -> { signed_in? && full_refresh? }
  end
  
  def refresh_user_from_sso
    return if Time.current.to_i < session[:last_user_refresh_from_sso].to_i + SSO_REFRESH_DELAY

    session[:last_user_refresh_from_sso] = Time.current.to_i
    Current.user.refresh_from_sso
  rescue => e
    Rails.logger.error "Error refreshing user info from SmallBets: #{e.message}. User: #{Current.user.inspect}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private
    def full_refresh?
      request.format.html? && !turbo_drive_request?
    end
  
    def turbo_drive_request?
      request.headers['Turbo-Frame'].present?
    end
end

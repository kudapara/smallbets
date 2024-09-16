module User::Sso
  extend ActiveSupport::Concern
  
  def sso_token_expired?
    sso_token_expires_at < Time.current
  end
  
  def refresh_from_sso
    return if sso_token.blank?

    sso_attributes = Sso::Fetch.new(token: sso_token).fetch(read_timeout: 1, open_timeout: 2)
    update(sso_attributes.except(:name, :email, :twitter_url, :linkedin_url, :personal_url))
  end
end

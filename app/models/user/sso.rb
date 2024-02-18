module User::Sso
  extend ActiveSupport::Concern
  
  def sso_linked?
    sso_user_id.present? && (sso_token_expires_at.blank? || sso_token_expires_at > Time.current)
  end
  
  def sso_token_expired?
    sso_token_expires_at < Time.current
  end
  
  def refresh_from_sso
    return if sso_token.blank? || sso_token_expired?

    sso_attributes = Sso::Fetch.new(token: sso_token).fetch(read_timeout: 1, open_timeout: 2)
    update(sso_attributes)
  end
end

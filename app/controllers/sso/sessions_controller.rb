class Sso::SessionsController < ApplicationController
  include NotifyBots
  
  allow_unauthenticated_access only: %i[ new ]
  rate_limit to: 10, within: 1.minute, only: :new, with: -> { render_rejection :too_many_requests }

  def new
    sso_attributes = Sso::Fetch.new(token: params[:token]).fetch
    
    if sso_attributes.present?
      user = User.active.find_or_initialize_by(sso_user_id: sso_attributes[:sso_user_id])
      user.update(sso_attributes)
      
      start_new_session_for user
      deliver_webhooks_to_bots(user, :created) if user.previously_new_record?
      redirect_to post_authenticating_url
    else
      render_rejection :unauthorized
    end
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error "Error creating/updating user from SmallBets: #{e.message}. SmallBets token: #{params[:token]}"
    Rails.logger.error e.backtrace.join("\n")
    
    render_rejection :unauthorized
  end

  private
    def render_rejection(status)
      flash.now[:alert] = "⛔️"
      render "sessions/new", status: status
    end
end

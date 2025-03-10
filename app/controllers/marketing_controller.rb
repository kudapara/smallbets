class MarketingController < ApplicationController
  allow_unauthenticated_access
  layout "marketing"

  before_action :restore_authentication, :redirect_signed_in_user_to_chat

  def show
    @user_count = User.active.non_suspended.count
  end
end

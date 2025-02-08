class MarketingController < ApplicationController
  allow_unauthenticated_access
  layout "marketing"

  def show
    @user_count = User.active.non_suspended.count
  end
end

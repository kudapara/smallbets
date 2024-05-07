class Users::ProfilesController < ApplicationController
  before_action :set_user

  def show
    @direct_memberships, @shared_memberships =
      Current.user.memberships.without_expired_threads.with_ordered_room.partition { |m| m.room.direct? }
    @thread_memberships, @shared_memberships = @shared_memberships.partition { |m| m.room.thread? }
    @thread_memberships.sort_by! { |m| m.room.created_at }
  end

  def update
    @user.update user_params
    redirect_to user_profile_url, notice: update_notice
  end

  private
    def set_user
      @user = Current.user
    end

    def user_params
      params.require(:user).permit(:name, :avatar, :email_address, :password, :bio).compact
    end

    def update_notice
      params[:user][:avatar] ? "It may take up to 30 minutes to change everywhere." : "✓"
    end
end

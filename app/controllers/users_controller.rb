class UsersController < ApplicationController
  require_unauthenticated_access only: %i[ new create ]

  before_action :set_user, only: :show
  before_action :verify_join_code, only: %i[ new create ]
  before_action :start_otp_if_user_exists, only: :create

  def new
    @user = User.new
  end

  def create
    @user = User.from_gumroad_sale(user_params)

    if @user
      start_new_session_for @user
      redirect_to root_url
    else
      redirect_to account_join_code_url, alert: "We couldn't find a sale for that email. Please try a different email or contact support@smallbets.com."
    end
  rescue ActiveRecord::RecordNotUnique
    user = User.find_by(email_address: user_params[:email_address])

    if user
      start_otp_for user
      redirect_to new_auth_tokens_validations_path
    else
      # Perhaps a duplicate order_id, needs manual review
      redirect_to account_join_code_url, alert: "We are having a problem logging you in. Please contact support@smallbets.com."
    end
  end

  def show
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def verify_join_code
      head :not_found if Current.account.join_code != params[:join_code]
    end
  
    def start_otp_if_user_exists
      user = User.find_by(email_address: user_params[:email_address])

      if user.present?
        start_otp_for user
        redirect_to new_auth_tokens_validations_path
      end
    end

    def start_otp_for(user)
      session[:otp_email_address] = user.email_address

      auth_token = user.auth_tokens.create!(expires_at: 15.minutes.from_now)
      auth_token.deliver_later
    end

    def user_params
      params.require(:user).permit(:name, :avatar, :email_address)
    end
end

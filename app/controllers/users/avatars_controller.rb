class Users::AvatarsController < ApplicationController
  include ActiveStorage::Streaming

  rescue_from(ActiveSupport::MessageVerifier::InvalidSignature) { head :not_found }

  def show
    @user = User.from_avatar_token(params[:user_id])

    if stale?(etag: @user)
      expires_in 30.minutes, public: true, stale_while_revalidate: 1.week

      if @user.bot?
        render_bot
      else
        render_initials
      end
    end
  end

  def destroy
    Current.user.avatar.destroy
    redirect_to user_profile_url
  end

  private
    SQUARE_WEBP_VARIANT = { resize_to_limit: [ 512, 512 ], format: :webp }

    def send_webp_blob_file(key)
      send_file ActiveStorage::Blob.service.path_for(key), content_type: "image/webp", disposition: :inline
    end
  
    def render_bot
      if @user.avatar.attached?
        avatar_variant = @user.avatar.variant(SQUARE_WEBP_VARIANT).processed
        send_webp_blob_file avatar_variant.key
      else
        render_default_bot
      end
    end

    def render_default_bot
      send_file Rails.root.join("app/assets/images/default-bot-avatar.svg"), content_type: "image/svg+xml", disposition: :inline
    end

    def render_initials
      render formats: :svg
    end
end

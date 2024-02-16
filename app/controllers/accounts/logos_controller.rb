class Accounts::LogosController < ApplicationController
  include ActiveStorage::Streaming, ActionView::Helpers::AssetUrlHelper

  allow_unauthenticated_access only: :show
  before_action :ensure_can_administer, only: :destroy

  def show
    if stale?(etag: Current.account)
      expires_in 5.minutes, public: true, stale_while_revalidate: 1.week

      if Current.account&.logo&.attached?
        logo_variant = Current.account.logo.variant(SQUARE_PNG_VARIANT).processed
        send_png_file ActiveStorage::Blob.service.path_for(logo_variant.key)
      else
        send_stock_icon
      end
    end
  end

  def destroy
    Current.account.logo.destroy
    redirect_to edit_account_url
  end

  private
    SQUARE_PNG_VARIANT = { resize_to_limit: [ 512, 512 ], format: :png }

    def send_png_file(path)
      send_file path, content_type: "image/png", disposition: :inline
    end

    def send_stock_icon
      case params[:type]
      when "favicon"
        send_png_file logo_path("favicon.png")
      when "apple-touch"
        send_png_file logo_path("apple-touch-icon.png")
      else
        send_png_file logo_path("app-icon.png")
      end
    end

    def logo_path(filename)
      Rails.root.join("app/assets/images/logos/#{filename}")
    end
end

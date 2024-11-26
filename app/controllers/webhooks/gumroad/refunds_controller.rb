class Webhooks::Gumroad::RefundsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  before_action :verify_webhook_secret
  before_action :ignore_unrelated_products

  def create
    event = WebhookEvent.create!(
      source: "gumroad",
      event_type: "refund",
      payload: params.to_unsafe_h
    )

    Gumroad::ProcessRefundJob.perform_later(event)

    render json: { status: "success" }, status: :ok
  rescue StandardError => e
    Rails.logger.error("ERROR: Failed to process Gumroad refund webhook: #{e.message}")
    render json: { status: "error", message: e.message }, status: :internal_server_error
  end

  private

  def verify_webhook_secret
    unless params[:webhook_secret] == ENV['WEBHOOK_SECRET']
      Rails.logger.warn("ERROR: Unauthorized webhook attempt #{params.inspect}")
      render json: { status: "error", message: "Unauthorized" }, status: :unauthorized
    end
  end
  
  def ignore_unrelated_products
    if params["product_id"].to_s != ENV["GUMROAD_PRODUCT_ID"].to_s
      Rails.logger.info("Ignored webhook for unrelated product_id: #{params["product_id"]}")
      render(json: { status: "ignored" }, status: :ok)
    end
  end
end

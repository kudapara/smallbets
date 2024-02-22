class Messages::BoostsController < ApplicationController
  include NotifyBots
  
  before_action :set_message

  def index
  end

  def new
  end

  def create
    @boost = @message.boosts.create!(boost_params)

    broadcast_create
    deliver_webhooks_to_bots(@boost, :created)
    redirect_to message_boosts_url(@message)
  end

  def destroy
    @boost = Current.user.boosts.find(params[:id])
    @boost.destroy!

    broadcast_remove
    deliver_webhooks_to_bots(@boost, :deleted)
  end

  private
    def set_message
      @message = Current.user.reachable_messages.find(params[:message_id])
    end

    def boost_params
      params.require(:boost).permit(:content)
    end

    def broadcast_create
      @boost.broadcast_append_to @boost.message.room, :messages,
        target: "boosts_message_#{@boost.message.client_message_id}", partial: "messages/boosts/boost", attributes: { maintain_scroll: true }
    end

    def broadcast_remove
      @boost.broadcast_remove_to @boost.message.room, :messages
    end
end

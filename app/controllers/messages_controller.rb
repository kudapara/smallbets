class MessagesController < ApplicationController
  include ActiveStorage::SetCurrent, RoomScoped, NotifyBots, Threads::Broadcasts

  before_action :set_room, except: :create
  before_action :set_message, only: %i[ show edit update destroy ]
  before_action :ensure_can_administer, only: %i[ edit update destroy ]

  layout false, only: :index

  def index
    @messages = find_paged_messages

    if @messages.any?
      fresh_when @messages
    else
      head :no_content
    end
  end

  def create
    set_room
    @message = @room.messages.create_with_attachment!(message_params)

    @message.broadcast_create
    broadcast_update_message_involvements(@message)
    broadcast_unexpire_thread if @room.expired?
    deliver_webhooks_to_bots(@message, :created)
  rescue ActiveRecord::RecordNotFound
    render action: :room_not_found
  end

  def show
  end

  def edit
  end

  def update
    @message.update!(message_params)

    @message.containing_rooms.each do |room|
      @message.broadcast_replace_to room, :messages, target: [ @message, :presentation ], partial: "messages/presentation", attributes: { maintain_scroll: true }
    end
    broadcast_update_message_involvements(@message)
    deliver_webhooks_to_bots(@message, :updated)
    redirect_to room_message_url(@room, @message)
  end

  def destroy
    @message.threads.each do |thread|
      broadcast_remove_to :rooms, target: [ thread, :list_node ]
    end
    @message.destroy
    @message.broadcast_remove_to @room, :messages
    deliver_webhooks_to_bots(@message, :deleted)
  end

  private
    def set_message
      @message = @room.messages_with_parent.find(params[:id])
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@message)
    end


    def find_paged_messages
      case
      when params[:before].present?
        @room.messages_with_parent.with_threads.with_creator.page_before(@room.messages_with_parent.find(params[:before]))
      when params[:after].present?
        @room.messages_with_parent.with_threads.with_creator.page_after(@room.messages_with_parent.find(params[:after]))
      else
        @room.messages_with_parent.with_threads.with_creator.last_page
      end
    end

    def broadcast_unexpire_thread
      @room.memberships.visible.each do |membership|
        refresh_shared_rooms(membership.user)
      end
    end

    def message_params
      params.require(:message).permit(:body, :attachment, :client_message_id)
    end
end

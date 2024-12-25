class MessagesController < ApplicationController
  include ActiveStorage::SetCurrent, RoomScoped, NotifyBots, Threads::Broadcasts

  before_action :set_room, only: %i[ index create destroy ]
  before_action :set_room_if_found, only: %i[ show edit update ]
  before_action :set_message, only: %i[ show edit update destroy ]
  before_action :ensure_can_administer, only: %i[ edit update destroy ]

  layout false, only: :index

  def index
    @messages = Bookmark.populate_for(find_paged_messages)

    head :no_content if @messages.blank?
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

    presentation_html = render_to_string(partial: "messages/presentation", locals: { message: @message })
    @message.containing_rooms.each do |room|
      @message.broadcast_replace_to room, :messages, target: [ @message, :presentation ], html: presentation_html, attributes: { maintain_scroll: true }
    end
    @message.broadcast_replace_to :inbox, target: [ @message, :presentation ], html: presentation_html, attributes: { maintain_scroll: true }
    broadcast_update_message_involvements(@message)
    deliver_webhooks_to_bots(@message, :updated)

    redirect_to @room ? room_message_url(@room, @message) : @message
  end

  def destroy
    @message.threads.each do |thread|
      [:inbox, :shared_rooms].each do |list_name|
        broadcast_remove_to :rooms, target: [thread, helpers.dom_prefix(list_name, :list_node)]
      end
    end
    @message.deactivate
    @message.broadcast_remove_to @room, :messages
    @message.broadcast_remove_to :inbox
    deliver_webhooks_to_bots(@message, :deleted)
  end

  private
    def set_message
      if @room
        @message = @room.messages_with_parent.find(params[:id])
      else
        @message = Current.user.reachable_messages.find(params[:id])
      end
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
      @room.memberships.active.visible.each do |membership|
        refresh_shared_rooms(membership.user)
      end
    end

    def message_params
      params.require(:message).permit(:body, :attachment, :client_message_id)
    end
end

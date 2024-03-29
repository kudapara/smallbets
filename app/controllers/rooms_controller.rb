class RoomsController < ApplicationController
  before_action :set_room, only: %i[ edit update show destroy ]
  before_action :ensure_can_administer, only: %i[ update destroy ]
  before_action :remember_last_room_visited, only: :show

  def index
    redirect_to room_url(Current.user.rooms.last)
  end

  def show
    @messages = find_messages
  end

  def destroy
    @room.parent_message&.touch
    @room.destroy

    broadcast_remove_room
    broadcast_update_parent_message
    redirect_to root_url
  end

  private
    def set_room
      if room = Current.user.rooms.find_by(id: params[:room_id] || params[:id])
        @room = room
      else
        redirect_to root_url, alert: "Room not found or inaccessible"
      end
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@room)
    end

    def find_messages
      messages = @room.messages_with_parent.with_threads.with_creator

      if show_first_message = messages.find_by(id: params[:message_id])
        @messages = messages.page_around(show_first_message)
      else
        @messages = messages.last_page
      end
    end

    def room_params
      params.require(:room).permit(:name)
    end

    def broadcast_remove_room
      broadcast_remove_to :rooms, target: [ @room, :list ]
    end
  
    def broadcast_update_parent_message
      if @room.thread?
        @room.parent_message.broadcast_replace_to @room.parent_message.room, :messages, target: [@room.parent_message, :threads], partial: "messages/threads", attributes: { maintain_scroll: true }
      end
    end
end

class Messages::BookmarksController < ApplicationController
  before_action :set_message

  def create
    @bookmark = @message.bookmarks.find_or_create_by(user: Current.user)

    broadcast_message_update
  end

  def destroy
    @message.bookmarks.where(user_id: Current.user.id).destroy_all
    
    broadcast_message_update
  end

  private
    def set_message
      @message = Current.user.reachable_messages.find(params[:message_id])
    end

    def broadcast_message_update
      html = render_to_string(partial: "messages/actions/bookmark", locals: { message: @message })
      @message.containing_rooms.each do |room|
        @message.broadcast_replace_to Current.user, room, :messages, target: [@message, :bookmarking], html: html
      end
      @message.broadcast_replace_to Current.user, :inbox, target: [@message, :bookmarking], html: html
    end
end

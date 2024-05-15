class Inboxes::MessagesController < InboxesController
  layout false
  
  def index
    @messages = find_messages

    render 'inboxes/messages/index'
  end
end
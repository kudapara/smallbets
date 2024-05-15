class Inboxes::NotificationsController < InboxesController
  layout false
  
  def index
    @messages = find_notifications

    render 'inboxes/messages/index'
  end
end
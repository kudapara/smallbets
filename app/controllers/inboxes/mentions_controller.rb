class Inboxes::MentionsController < InboxesController
  layout false
  
  def index
    @messages = find_mentions
    
    render 'inboxes/messages/index'
  end
end
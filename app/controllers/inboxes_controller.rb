class InboxesController < ApplicationController
  def show
    redirect_to mentions_inbox_path
  end
  
  def mentions
    @messages = find_mentions
  end

  def notifications
    @messages = find_notifications
  end

  def messages
    @messages = find_messages
  end
  
  private
    def find_mentions
      paginate Current.user.mentions.with_threads.with_creator
    end

    def find_notifications
      paginate Current.user.reachable_messages.with_threads.with_creator
                      .merge(Membership.notifications_on)
                      .joins(:room).merge(Room.without_directs)
    end
  
    def find_messages
      paginate Current.user.reachable_messages.with_threads.with_creator
                      .merge(Membership.visible)
                      .joins(:room).merge(Room.without_directs)
    end
  
    def paginate(messages)
      case
      when params[:before].present?
        messages.page_before(messages.find(params[:before]))
      when params[:after].present?
        messages.page_after(messages.find(params[:after]))
      else
        messages.last_page
      end
    end
end
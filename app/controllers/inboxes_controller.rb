class InboxesController < ApplicationController
  def show
    clear_last_loaded_message_timestamps
    redirect_to mentions_inbox_path
  end

  def mentions
    @messages = find_mentions
    session[:inbox_last_loaded_mention_created_at] = (@messages.last&.created_at || Time.current).iso8601(6)
  end

  def notifications
    @messages = find_notifications
    session[:inbox_last_loaded_notification_created_at] = (@messages.last&.created_at || Time.current).iso8601(6)
  end

  def messages
    @messages = find_messages
    session[:inbox_last_loaded_message_created_at] = (@messages.last&.created_at || Time.current).iso8601(6)
  end

  def clear
    Current.user.memberships.unread.each { |m| m.read_until(now_if_stale(session[:inbox_last_loaded_message_created_at])) }
    Current.user.memberships.notifications_on.unread.each { |m| m.read_until(now_if_stale(session[:inbox_last_loaded_notification_created_at])) }

    mentions_loaded_until = now_if_stale(session[:inbox_last_loaded_mention_created_at])
    Current.user.memberships.unread.each do |m|
      non_mentions = m.room.messages.joins("LEFT JOIN mentions ON mentions.message_id = messages.id")
          .where("mentions.user_id IS NULL OR mentions.user_id != ?", Current.user.id)
          .where(created_at: m.unread_at..mentions_loaded_until)

      m.read_until(mentions_loaded_until) if non_mentions.none?
    end

    redirect_back fallback_location: mentions_inbox_path
  end

  private
    def find_mentions
      paginate Current.user.mentions.with_threads.with_creator
    end

    def find_notifications
      paginate Current.user.reachable_messages.with_threads.with_creator
                      .merge(Membership.notifications_on)
    end
  
    def find_messages
      paginate Current.user.reachable_messages.with_threads.with_creator
                      .merge(Membership.visible)
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
  
    def clear_last_loaded_message_timestamps
      session[:inbox_last_loaded_mention_created_at] = nil
      session[:inbox_last_loaded_notification_created_at] = nil
      session[:inbox_last_loaded_message_created_at] = nil
    end

    def now_if_stale(time)
      time = Time.iso8601(time) if time.present?
      (time.present? && time > 1.hour.ago) ? time : Time.current
    end
end

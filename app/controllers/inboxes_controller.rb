class InboxesController < ApplicationController
  before_action :set_message_pagination_anchors, only: %i[ mentions notifications messages ]
  before_action :set_bookmark_pagination_anchors, only: %i[ bookmarks ]
  
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

  def bookmarks
    @messages = find_bookmarked_messages
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
      paginate Current.user.mentions.without_created_by(Current.user).with_threads.with_creator
    end

    def find_notifications
      paginate Current.user.reachable_messages
                      .without_created_by(Current.user)
                      .with_threads.with_creator
                      .merge(Membership.notifications_on)
    end
  
    def find_messages
      paginate Current.user.reachable_messages
                      .without_created_by(Current.user)
                      .with_threads.with_creator
                      .merge(Membership.visible)
    end

    def find_bookmarked_messages
      bookmarks = paginate Current.user.bookmarks.includes(:message).merge(Message.with_threads.with_creator)
      bookmarks.map(&:message)
    end
  
    def paginate(records)
      case
      when params[:before].present?
        records.page_before(@before)
      when params[:after].present?
        records.page_after(@after)
      else
        records.last_page
      end
    end
  
    def set_message_pagination_anchors
      @before = Message.find_by(id: params[:before])
      @after = Message.find_by(id: params[:after])
    end

    def set_bookmark_pagination_anchors
      @before = Message.find_by(id: params[:before])&.bookmarks&.find_by(user_id: Current.user.id)
      @after = Message.find_by(id: params[:after])&.bookmarks&.find_by(user_id: Current.user.id)
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

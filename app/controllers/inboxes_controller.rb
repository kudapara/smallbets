class InboxesController < ApplicationController
  before_action :set_message_pagination_anchors, only: %i[ mentions notifications messages ]
  before_action :set_bookmark_pagination_anchors, only: %i[ bookmarks ]
  before_action :set_sidebar_variables
  before_action :ensure_is_expert, only: %i[ answers ]

  def show
    clear_last_loaded_message_timestamps

    redirect_to mentions_inbox_path
  end

  def mentions
    @messages = find_mentions

    track_last_loaded_message :inbox_last_loaded_mention_created_at
  end

  def answers
    @messages = find_answers
    @answer_count = Current.user.reachable_messages.where(answered_by: Current.user).count
  end

  def notifications
    @messages = find_notifications

    track_last_loaded_message :inbox_last_loaded_notification_created_at
  end

  def messages
    @messages = find_messages

    track_last_loaded_message :inbox_last_loaded_message_created_at
  end

  def bookmarks
    @messages = find_bookmarked_messages
  end

  def clear
    Current.user.memberships.unread.each { |m| m.read_until(now_if_stale(session[:inbox_last_loaded_message_created_at])) }
    Current.user.memberships.notifications_on.unread.each { |m| m.read_until(now_if_stale(session[:inbox_last_loaded_notification_created_at])) }

    mentions_loaded_until = now_if_stale(session[:inbox_last_loaded_mention_created_at])
    Current.user.memberships.unread.each do |m|
      non_mentions = m.room.messages.without_user_mentions(Current.user).between(m.unread_at, mentions_loaded_until)

      m.read_until(mentions_loaded_until) if non_mentions.none?
    end

    redirect_back(fallback_location: mentions_inbox_path) unless params[:stay] 
  end

  private
    def set_sidebar_variables
      memberships = Current.user.memberships.visible.without_thread_rooms.with_has_unread_notifications.includes(:room)
      
      # Get all direct memberships and filter them
      all_direct_memberships = memberships.select { |m| m.room.direct? }
      @direct_memberships = filter_direct_memberships(all_direct_memberships)
      
      # Get other memberships using the without_direct_rooms scope
      other_memberships = Current.user.memberships.visible.without_thread_rooms.without_direct_rooms.with_has_unread_notifications.includes(:room)
      @all_memberships = other_memberships.with_room_by_last_active_newest_first
      @starred_memberships = other_memberships.with_room_by_last_active_newest_first

      @direct_memberships.select! { |m| m.room.messages_count > 0 }
    end

    def filter_direct_memberships(direct_memberships)
      # Filter direct memberships to only include:
      # 1. Memberships with unread messages
      # 2. Memberships updated in the last 7 days
      direct_memberships.select do |membership|
        membership.unread? || 
        membership.has_unread_notifications? || 
        (membership.room.updated_at.present? && membership.room.updated_at >= 7.days.ago)
      end.sort_by { |m| m.room.updated_at || Time.at(0) }.reverse
    end

    def find_mentions
      Bookmark.populate_for paginate(Current.user.mentioning_messages.without_created_by(Current.user).with_threads.with_creator)
    end

    def find_notifications
      Bookmark.populate_for paginate(Current.user.reachable_messages
                                            .without_created_by(Current.user)
                                            .with_threads.with_creator
                                            .merge(Membership.active.notifications_on))
    end

    def find_messages
      Bookmark.populate_for paginate(Current.user.reachable_messages
                                            .without_created_by(Current.user)
                                            .with_threads.with_creator
                                            .merge(Membership.active.visible))
    end

    def find_bookmarked_messages
      bookmarks = paginate Current.user.bookmarks.includes(:message).merge(Message.with_threads.with_creator).where(message: { active: true })
      Bookmark.populate_for(bookmarks.map(&:message))
    end

    def find_answers
      Bookmark.populate_for paginate(Current.user.reachable_messages.where(answered_by: Current.user).with_threads.with_creator)
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
      @before = Message.active.find_by(id: params[:before])
      @after = Message.active.find_by(id: params[:after])
    end

    def set_bookmark_pagination_anchors
      @before = Bookmark.active.find_by(message_id: params[:before], user_id: Current.user.id) if params[:before].present?
      @after = Bookmark.active.find_by(message_id: params[:after], user_id: Current.user.id) if params[:after].present?
    end

    def track_last_loaded_message(key)
      session[key] = (@messages.last&.created_at || Time.current).iso8601(6)
    end

    def clear_last_loaded_message_timestamps
      session.delete :inbox_last_loaded_mention_created_at
      session.delete :inbox_last_loaded_notification_created_at
      session.delete :inbox_last_loaded_message_created_at
    end

    def now_if_stale(time)
      return Time.current unless time.present?

      time = Time.iso8601(time)
      time > 1.hour.ago ? time : Time.current
    end

    def ensure_is_expert
      head :forbidden unless Current.user.expert? || Current.user.administrator?
    end
end

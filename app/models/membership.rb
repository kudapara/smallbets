class Membership < ApplicationRecord
  include Connectable, Deactivatable

  belongs_to :room
  belongs_to :user

  has_many :unread_notifications, ->(membership) {
    next none if membership.involved_in_invisible?

    since(membership.unread_at || Time.current).mentioning(membership.user_id)
  }, through: :room, source: :messages

  scope :with_has_unread_notifications, -> {
    select(
      "memberships.*",

      <<~SQL.squish + " AS preloaded_has_unread_notifications"
        EXISTS (
          SELECT 1
          FROM messages
          JOIN mentions ON mentions.message_id = messages.id
          WHERE messages.room_id = memberships.room_id
            AND memberships.involvement NOT IN ('invisible')
            AND mentions.user_id = memberships.user_id
            AND messages.created_at >= COALESCE(
              memberships.unread_at,
              '#{Time.current.utc.iso8601}'
            )
        )
      SQL
    )
  }

  after_update_commit { user.reset_remote_connections if deactivated? }
  after_destroy_commit { user.reset_remote_connections }

  enum involvement: %w[ invisible nothing mentions everything ].index_by(&:itself), _prefix: :involved_in

  after_update :make_parent_involvements_visible, if: -> { saved_change_to_involvement? && involvement_before_last_save.inquiry.invisible? }
  after_update :set_nested_involvements_to_mentions, if: -> { saved_change_to_involvement? && involved_in_invisible? }
  after_update :broadcast_involvement, if: :saved_change_to_involvement?
  

  scope :with_ordered_room, -> { includes(:room).joins(:room).order("rooms.sortable_name") }
  scope :with_room_by_activity, -> { includes(:room).joins(:room).order("messages_count DESC") }
  scope :with_room_by_last_active_oldest_first, -> { includes(:room).joins(:room).order("rooms.last_active_at") }
  scope :with_room_by_last_active_newest_first, -> { includes(:room).joins(:room).order("rooms.last_active_at DESC") }
  scope :with_room_chronologically, -> { includes(:room).joins(:room).order("rooms.created_at") }
  scope :with_room_by_sort_preference, -> (preference) {
    case preference
    when "alphabetical"
      with_ordered_room
    when "most_active"
      with_room_by_activity
    else
      with_room_by_last_active_newest_first
    end
  }
  scope :without_direct_rooms, -> { joins(:room).where.not(rooms: { type: "Rooms::Direct" }) }
  scope :without_thread_rooms, -> { joins(:room).where.not(rooms: { type: "Rooms::Thread" }) }
  scope :thread_rooms, -> { joins(:room).where(rooms: { type: "Rooms::Thread" }) }
  scope :without_expired_threads, -> { joins(:room).where("rooms.type != 'Rooms::Thread' or rooms.last_active_at > ?", Room::EXPIRES_INTERVAL.ago) }
  scope :with_active_threads, -> { joins(:room).where("rooms.type == 'Rooms::Thread' and rooms.last_active_at > ?", Room::EXPIRES_INTERVAL.ago) }

  scope :notifications_on, -> { where(involvement: :everything) }
  scope :visible, -> { where.not(involvement: :invisible) }
  scope :read,  -> { where(unread_at: nil) }
  scope :unread,  -> { where.not(unread_at: nil) }

  def read_until(time)
    return if read? || time < unread_at
    
    update!(unread_at: room.messages.ordered.where("created_at > ?", time).first&.created_at)
    broadcast_read if read?
  end

  def mark_unread_at(message)
    update!(unread_at: message.created_at)
    broadcast_unread_by_user
  end

  def read
    update!(unread_at: nil)
    broadcast_read
  end
  
  def read?
    unread_at.blank?
  end
  
  def unread?
    unread_at.present?
  end
  
  def has_unread_notifications?
    unread? && unread_notifications.any?
  end
  
  def receives_mentions?
    involved_in_mentions? || involved_in_everything?
  end
  
  def ensure_receives_mentions!
    current_membership = self
    while current_membership.present?
      current_membership.update(involvement: :mentions) unless current_membership.receives_mentions?
      current_membership = current_membership.parent_membership
    end
  end

  def parent_membership
    return unless room.parent_room

    room.parent_room.memberships.create_with(involvement: "invisible").find_or_create_by(user: user)
  end

  # Top level parent in hierarchy
  def root_membership
    parent_membership.nil? ? self : parent_membership.root_membership
  end

  def set_nested_involvements_to_mentions
    room.threads.each do |thread|
      thread_membership = thread.memberships.find_by(user: user)
      next unless thread_membership
      thread_membership.update(involvement: :mentions) if thread_membership.involved_in_everything?
      thread_membership.set_nested_involvements_to_mentions
    end
  end

  def preloaded_has_unread_notifications?
    ActiveRecord::Type::Boolean.new.cast(self[:preloaded_has_unread_notifications])
  end
  
  private
  
  def broadcast_read
    ActionCable.server.broadcast "user_#{user_id}_reads", { room_id: room_id }
  end

  def broadcast_unread_by_user
    ActionCable.server.broadcast "user_#{user_id}_unreads", { roomId: room.id, roomSize: room.messages_count, roomUpdatedAt: room.last_active_at.iso8601, forceUnread: true }
    ActionCable.server.broadcast "user_#{user_id}_notifications", { roomId: room.id } if has_unread_notifications?
  end

  def broadcast_involvement
    ActionCable.server.broadcast "user_#{user_id}_involvements", { roomId: room_id, involvement: involvement }
  end
  
  def make_parent_involvements_visible
    current_membership = self
    while (current_membership = current_membership.parent_membership).present?
      current_membership.update(involvement: :mentions) if current_membership.involved_in_invisible?  
    end
  end
end

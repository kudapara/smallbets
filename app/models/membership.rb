class Membership < ApplicationRecord
  include Connectable

  belongs_to :room
  belongs_to :user

  has_many :unread_notifications, ->(membership) { 
    unread_messages = where("messages.created_at >= ?", membership.unread_at || Time.current)
    if membership.involved_in_nothing? || membership.involved_in_mentions?
      unread_messages = unread_messages.with_mentions.where(mentions: { user_id: membership.user_id })
    end
    unread_messages.none! if membership.involved_in_invisible?

    unread_messages
  }, through: :room, source: :messages

  after_destroy_commit { user.reset_remote_connections }

  enum involvement: %w[ invisible nothing mentions everything ].index_by(&:itself), _prefix: :involved_in

  after_update :make_parent_involvements_visible, if: -> { saved_change_to_involvement? && involvement_before_last_save.inquiry.invisible? }
  after_update :set_nested_involvements_to_mentions, if: -> { saved_change_to_involvement? && involved_in_invisible? }

  scope :with_ordered_room, -> { includes(:room).joins(:room).order("messages_count DESC") }
  scope :without_direct_rooms, -> { joins(:room).where.not(room: { type: "Rooms::Direct" }) }
  scope :without_thread_rooms, -> { joins(:room).where.not(room: { type: "Rooms::Thread" }) }
  scope :thread_rooms, -> { joins(:room).where(room: { type: "Rooms::Thread" }) }
  scope :without_expired_threads, -> { joins(:room).where("rooms.type != 'Rooms::Thread' or rooms.last_active_at > ?", Room::EXPIRES_INTERVAL.ago) }

  scope :notifications_on, -> { where(involvement: :everything) }
  scope :visible, -> { where.not(involvement: :invisible) }
  scope :read,  -> { where(unread_at: nil) }
  scope :unread,  -> { where.not(unread_at: nil) }

  def read_until(time)
    return if read? || time < unread_at
    
    update!(unread_at: room.messages.ordered.where("created_at > ?", time).first&.created_at)
    broadcast_read if read?
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

  def set_nested_involvements_to_mentions
    room.threads.each do |thread|
      thread_membership = thread.memberships.find_by(user: user)
      thread_membership.update(involvement: :mentions) if thread_membership.involved_in_everything?
      thread_membership.set_nested_involvements_to_mentions
    end
  end
  
  private
  
  def broadcast_read
    ActionCable.server.broadcast "user_#{user_id}_reads", { room_id: room_id }
  end
  
  def make_parent_involvements_visible
    current_membership = self
    while (current_membership = current_membership.parent_membership).present?
      current_membership.update(involvement: :mentions) if current_membership.involved_in_invisible?  
    end
  end
end

class Membership < ApplicationRecord
  include Connectable

  belongs_to :room
  belongs_to :user

  after_destroy_commit { user.reset_remote_connections }

  enum involvement: %w[ invisible nothing mentions everything ].index_by(&:itself), _prefix: :involved_in

  after_update :make_parent_involvements_visible, if: -> { saved_change_to_involvement? && involvement_before_last_save.inquiry.invisible? }

  scope :with_ordered_room, -> { includes(:room).joins(:room).order("messages_count DESC") }
  scope :without_direct_rooms, -> { joins(:room).where.not(room: { type: "Rooms::Direct" }) }
  scope :without_thread_rooms, -> { joins(:room).where.not(room: { type: "Rooms::Thread" }) }
  scope :thread_rooms, -> { joins(:room).where(room: { type: "Rooms::Thread" }) }
  scope :without_expired_threads, -> { joins(:room).where("rooms.type != 'Rooms::Thread' or rooms.last_active_at is null or rooms.last_active_at > ?", Room::EXPIRES_INTERVAL.ago) }

  scope :visible, -> { where.not(involvement: :invisible) }
  scope :unread,  -> { where.not(unread_at: nil) }

  def read
    update!(unread_at: nil)
  end
  
  def read?
    unread_at.blank?
  end
  
  def unread?
    unread_at.present?
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
  
  private
  
  def make_parent_involvements_visible
    current_membership = self
    while (current_membership = current_membership.parent_membership).present?
      current_membership.update(involvement: :mentions) if current_membership.involved_in_invisible?  
    end
  end
end

class Membership < ApplicationRecord
  include Connectable

  belongs_to :room
  belongs_to :user

  after_destroy_commit { user.reset_remote_connections }

  enum involvement: %w[ invisible nothing mentions everything ].index_by(&:itself), _prefix: :involved_in

  after_update :make_parent_involvements_visible, if: -> { saved_change_to_involvement? && involvement_before_last_save.inquiry.invisible? }
  after_update :make_nested_involvements_invisible, if: -> { saved_change_to_involvement? && involved_in_invisible? }

  scope :with_ordered_room, -> { includes(:room).joins(:room).order("messages_count DESC, rooms.created_at ASC") }
  scope :without_direct_rooms, -> { joins(:room).where.not(room: { type: "Rooms::Direct" }) }
  scope :thread_rooms, -> { joins(:room).where(room: { type: "Rooms::Thread" }) }

  scope :visible, -> { where.not(involvement: :invisible) }
  scope :unread,  -> { where.not(unread_at: nil) }

  def read
    update!(unread_at: nil)
  end

  def unread?
    unread_at.present?
  end
  
  private
  
  def parent_membership
    return unless room.parent_room
    
    room.parent_room.memberships.find_by(user: user)
  end

  def make_parent_involvements_visible
    parent_membership.update(involvement: :mentions) if parent_membership&.involved_in_invisible? 
  end
  
  def make_nested_involvements_invisible
    room.threads.each do |thread|
      thread.memberships.find_by(user: user).update(involvement: :invisible)
    end
  end
end

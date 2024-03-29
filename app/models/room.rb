class Room < ApplicationRecord
  has_many :memberships, dependent: :delete_all do
    def grant_to(users)
      room = proxy_association.owner
      Membership.insert_all(Array(users).collect { |user| { room_id: room.id, user_id: user.id, involvement: room.default_involvement(user: user) } })
      room.threads.find_each { |thread| thread.memberships.grant_to(users) }
    end

    def revoke_from(users)
      room = proxy_association.owner
      # Must use the `user_id: ...` condition and not `user: ...` for the hierarchical permissions to work 
      Membership.where(room_id: room.id, user_id: Array(users).map(&:id)).destroy_all
      room.threads.find_each { |thread| thread.memberships.revoke_from(users) }
    end

    def revise(granted: [], revoked: [])
      transaction do
        grant_to(granted) if granted.present?
        revoke_from(revoked) if revoked.present?
      end
    end
  end

  has_many :users, through: :memberships
  has_many :visible_memberships, -> { visible }, class_name: "Membership"
  has_many :visible_users, through: :visible_memberships, source: :user, class_name: "User"
  has_many :messages, dependent: :destroy
  has_many :threads, through: :messages, class_name: "Rooms::Thread", dependent: :destroy
  belongs_to :parent_message, class_name: "Message", optional: true, touch: true
  has_one :parent_room, through: :parent_message, source: :room, class_name: "Room"

  belongs_to :creator, class_name: "User", default: -> { Current.user }

  scope :opens,           -> { where(type: "Rooms::Open") }
  scope :closeds,         -> { where(type: "Rooms::Closed") }
  scope :directs,         -> { where(type: "Rooms::Direct") }
  scope :without_directs, -> { where.not(type: "Rooms::Direct") }

  scope :ordered, -> { order("LOWER(name)") }

  class << self
    def create_for(attributes, users:)
      transaction do
        create!(attributes).tap do |room|
          room.memberships.grant_to users
        end
      end
    end

    def original
      order(:created_at).first
    end
  end

  def receive(message)
    unread_memberships(message)
    push_later(message)
  end

  def open?
    is_a?(Rooms::Open)
  end

  def closed?
    is_a?(Rooms::Closed)
  end

  def direct?
    is_a?(Rooms::Direct)
  end

  def thread?
    is_a?(Rooms::Thread)
  end
  
  def default_involvement(user: nil)
    "mentions"
  end
  
  def messages_with_parent
    Message.where(room_id: id).or(Message.where(id: parent_message_id))
  end

  private
    def unread_memberships(message)
      memberships.visible.disconnected.where.not(user: message.creator).update_all(unread_at: message.created_at, updated_at: Time.current)
    end

    def push_later(message)
      Room::PushMessageJob.perform_later(self, message)
    end
end

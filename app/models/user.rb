class User < ApplicationRecord
  DEFAULT_NAME = "Small Better"
  
  include Avatar, Bot, Mentionable, Role, Transferable, Sso

  has_many :memberships, dependent: :delete_all
  has_many :rooms, through: :memberships

  has_many :reachable_messages, through: :rooms, source: :messages
  has_many :messages, dependent: :destroy, foreign_key: :creator_id
  has_and_belongs_to_many :mentions, ->(user) { where(room_id: user.room_ids) }, 
                          class_name: "Message", join_table: "mentions"

  has_many :push_subscriptions, class_name: "Push::Subscription", dependent: :delete_all

  has_many :boosts, dependent: :destroy, foreign_key: :booster_id
  has_many :searches, dependent: :delete_all

  has_many :sessions, dependent: :destroy

  scope :active, -> { where(active: true) }
  
  scope :without_default_names, -> { where.not(name: DEFAULT_NAME) }

  has_secure_password validations: false

  after_create_commit :grant_membership_to_open_rooms

  scope :ordered, -> { order("LOWER(name)") }
  scope :filtered_by, ->(query) { where("name like ? or twitter_username like ? or linkedin_username like ?", 
                                        "%#{query}%", "%#{query}%", "%#{query}%") if query.present? }
  
  after_initialize :set_default_name

  def initials
    name.scan(/\b\w/).join
  end

  def title
    [ name, bio ].compact_blank.join(" – ")
  end

  def twitter_url
    return unless twitter_username.present?

    "https://x.com/#{twitter_username}"
  end
  
  def linkedin_url
    return unless linkedin_username.present?
    
    "https://linkedin.com/in/#{linkedin_username}"
  end

  def deactivate
    transaction do
      close_remote_connections

      memberships.without_direct_rooms.delete_all
      push_subscriptions.delete_all
      searches.delete_all
      sessions.delete_all

      update! active: false, email_address: deactived_email_address
    end
  end

  def deactivated?
    !active?
  end

  def reset_remote_connections
    close_remote_connections reconnect: true
  end
  
  def member_of?(room)
    Membership.visible.exists?(room_id: room.id, user_id: id)
  end

  private
    def grant_membership_to_open_rooms
      Membership.insert_all(Rooms::Open.pluck(:id).collect { |room_id| { room_id: room_id, user_id: id } })
      Rooms::Thread.joins(:parent_room).where(parent_room: { type: "Rooms::Open" }).find_each do |thread|
        thread.memberships.grant_to(self)
      end
    end

    def deactived_email_address
      email_address&.gsub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end

    def close_remote_connections(reconnect: false)
      ActionCable.server.remote_connections.where(current_user: self).disconnect reconnect: reconnect
    end
  
    def set_default_name
      self.name ||= DEFAULT_NAME
    end
end

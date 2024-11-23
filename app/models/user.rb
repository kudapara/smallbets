class User < ApplicationRecord
  DEFAULT_NAME = "Small Better"

  include Avatar, Bot, Mentionable, Role, Transferable, Sso, Deactivatable

  has_many :memberships, -> { active }, class_name: "Membership"
  has_many :rooms, -> { active }, through: :memberships, source: :room

  has_many :bookmarks, -> { active }, class_name: "Bookmark"
  has_many :bookmarked_messages, -> { order("bookmarks.created_at DESC") }, through: :bookmarks, source: :message
  has_many :reachable_messages, through: :rooms, source: :messages
  has_many :messages, -> { active }, foreign_key: :creator_id, class_name: "Message"
  has_and_belongs_to_many :mentions, ->(user) { where(room_id: user.room_ids) },
                          class_name: "Message", join_table: "mentions"

  has_many :push_subscriptions, class_name: "Push::Subscription", dependent: :delete_all

  has_many :boosts, -> { active }, foreign_key: :booster_id, class_name: "Boost"
  has_many :searches, dependent: :delete_all

  has_many :sessions, dependent: :destroy
  has_many :auth_tokens, dependent: :destroy

  scope :without_default_names, -> { where.not(name: DEFAULT_NAME) }

  has_secure_password validations: false

  before_validation :set_default_name
  before_validation :normalize_social_urls
  before_save :transliterate_name, if: :name_changed?
  after_create_commit :grant_membership_to_open_rooms

  scope :ordered, -> { order("LOWER(name)") }
  scope :recent_posters_first, ->(room_id = nil) do
    messages_table = Message.active.arel_table
    users_table = active.arel_table

    left_join_condition = messages_table[:creator_id].eq(users_table[:id])
    left_join_condition = left_join_condition.and(messages_table[:room_id].eq(room_id)) if room_id.present?

    left_join = users_table.join(messages_table, Arel::Nodes::OuterJoin).on(left_join_condition)

    joins(left_join.join_sources)
      .group(users_table[:id])
      .order(messages_table[:created_at].maximum.desc)
  end
  scope :filtered_by, ->(query) { where("name like ? or ascii_name like ? or twitter_username like ? or linkedin_username like ?",
                                        "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%") if query.present? }

  def self.from_gumroad_sale(attributes)
    return User.create!(attributes) if ENV["GUMROAD_OFF"] || true

    sale = GumroadAPI.sales(email: attributes[:email_address]).first
    User.create!(attributes.merge(membership_started_at: sale["created_at"], order_id: sale["id"])) if sale
  end

  def initials
    name.scan(/\b\w/).join
  end

  def title
    [ name, bio ].compact_blank.join(" – ")
  end

  def reactivate
    transaction do
      memberships.without_direct_rooms.update!(active: true)

      update! active: true, email_address: reactivated_email_address

      reset_remote_connections
    end
  end

  def deactivate
    transaction do
      close_remote_connections

      memberships.without_direct_rooms.update!(active: false)
      push_subscriptions.delete_all
      searches.delete_all
      sessions.delete_all

      update! active: false, email_address: deactived_email_address
    end
  end

  def reset_remote_connections
    close_remote_connections reconnect: true
  end

  def member_of?(room)
    Membership.active.visible.exists?(room_id: room.id, user_id: id)
  end

  def default_name?
    name == DEFAULT_NAME
  end

  def editable_name
    default_name? ? "" : name
  end
  
  def joined_at
    membership_started_at || created_at
  end

  private
    def grant_membership_to_open_rooms
      Membership.insert_all(Rooms::Open.pluck(:id).collect { |room_id| { room_id: room_id, user_id: id } })
      Rooms::Thread.joins(:parent_room).where(parent_room: { type: "Rooms::Open" }).find_each do |thread|
        thread.memberships.grant_to(self)
      end
    end

    def reactivated_email_address
      email_address&.gsub(/-deactivated-.+@/, "@")
    end

    def deactived_email_address
      email_address&.gsub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end

    def close_remote_connections(reconnect: false)
      ActionCable.server.remote_connections.where(current_user: self).disconnect reconnect: reconnect
    end

    def set_default_name
      self.name = name.presence || DEFAULT_NAME
    end

    def transliterate_name
      self.ascii_name = name.to_s.to_ascii
    end

    def normalize_social_urls
      self.twitter_url = clean_twitter_url(twitter_url)
      self.linkedin_url = clean_linkedin_url(linkedin_url)
    end

    def clean_twitter_url(url)
      return nil if url.blank?
      return url.strip if url.include?("/")

      handle = url.gsub(/^@/, "").strip
      "https://x.com/#{handle}"
    end

    def clean_linkedin_url(url)
      return nil if url.blank?
      return url.strip if url.strip.match?(/\/.+/)

      handle = url.strip
      "https://www.linkedin.com/in/#{handle}"
    end
end

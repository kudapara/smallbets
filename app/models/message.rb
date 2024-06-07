class Message < ApplicationRecord
  include Attachment, Broadcasts, Mentionee, Pagination, Searchable

  belongs_to :room, touch: :last_active_at, counter_cache: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :boosts, dependent: :destroy
  has_many :bookmarks

  has_many :threads, class_name: "Rooms::Thread", foreign_key: :parent_message_id, dependent: :destroy

  has_rich_text :body

  before_create -> { self.client_message_id ||= Random.uuid } # Bots don't care
  after_create_commit -> { room.receive(self) }

  after_create -> { involve_mentionees_in_room(unread: true) }
  after_update -> { involve_mentionees_in_room(unread: false) }
  after_save -> { involve_author_in_thread }, if: -> { room.thread? }

  scope :ordered, -> { order(:created_at) }
  scope :with_creator, -> { includes(:creator) }
  scope :with_threads, -> { includes(:threads) }
  scope :without_created_by, ->(user) { where.not(creator_id: user.id) }
  scope :between, ->(from, to) { where(created_at: from..to) }

  attr_accessor :bookmarked
  alias_method :bookmarked?, :bookmarked

  def containing_rooms
    Room.where(id: room_id).or(Room.where(parent_message_id: id))
  end
  
  def bookmarked_by_current_user?
    return bookmarked? unless bookmarked.nil?
    
    bookmarks.find_by(user_id: Current.user.id).present?
  end
  
  def plain_text_body
    body.to_plain_text.presence || attachment&.filename&.to_s || ""
  end

  def to_key
    [ client_message_id ]
  end

  def content_type
    case
    when attachment?    then "attachment"
    when sound.present? then "sound"
    else                     "text"
    end.inquiry
  end

  def sound
    plain_text_body.match(/\A\/play (?<name>\w+)\z/) do |match|
      Sound.find_by_name match[:name]
    end
  end
  
  private

  def involve_mentionees_in_room(unread:)
    mentionees.each { |user| room.involve_user(user, unread: unread) }
  end

  def involve_author_in_thread
    room.involve_user(creator)
  end
end

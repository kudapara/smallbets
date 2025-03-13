module Message::Mentionee
  extend ActiveSupport::Concern

  included do
    has_many :mentions, dependent: :destroy
    has_many :mentionees, ->(message) { where(id: message.room.user_ids) }, through: :mentions, source: :user

    after_save :create_mentionees
    
    scope :mentioning, ->(user_id) {
      joins(:mentions).where(mentions: { user_id: user_id })
    }
    scope :without_user_mentions, ->(user) {
      left_outer_joins(:mentions).where.not(mentions: { user_id: user.id }).distinct
    }
  end

  private
    def create_mentionees
      self.mentionees = mentioned_users
    end

    def mentioned_users
      if body.body
        (body.body.attachables.grep(User) + cited_users).uniq
      else
        []
      end
    end

    def cited_users
      cited_message_ids = body.body.fragment.find_all("cite a").map { |a| a["href"].to_s[/@([^@]+)$/, 1] }
      User.joins(:messages).where.not(id: self.creator_id).where(messages: { id: cited_message_ids }).distinct
    end
end

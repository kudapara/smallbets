module Message::Mentionee
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :mentionees, ->(message) { where(id: message.room.user_ids) }, 
                            class_name: "User", join_table: "mentions"

    after_save :create_mentionees
    
    scope :with_mentions, ->{ joins("JOIN mentions ON mentions.message_id = messages.id") }
    scope :without_user_mentions, ->(user) {
      joins("LEFT JOIN mentions ON mentions.message_id = messages.id")
        .where("mentions.user_id IS NULL OR mentions.user_id != ?", user.id)
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

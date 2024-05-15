module Message::Mentionee
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :mentionees, ->(message) { where(id: message.room.user_ids) }, 
                            class_name: "User", join_table: "mentions"

    after_save :create_mentionees
  end

  private
    def create_mentionees
      self.mentionees = mentioned_users
    end

    def mentioned_users
      if body.body
        body.body.attachables.grep(User).uniq
      else
        []
      end
    end
end

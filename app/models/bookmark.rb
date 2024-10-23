class Bookmark < ApplicationRecord
  include Pagination, Deactivatable

  belongs_to :user
  belongs_to :message

  scope :ordered, -> { order(:created_at) }

  def self.populate_for(messages)
    bookmarked_message_ids = Current.user.bookmarked_messages.where(id: messages.map(&:id)).pluck(:id).to_set
    messages.to_a.each { |message| message.bookmarked = bookmarked_message_ids.include?(message.id) }
  end
end

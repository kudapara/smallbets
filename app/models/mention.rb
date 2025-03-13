class Mention < ApplicationRecord
  belongs_to :user
  belongs_to :message
  
  scope :not_notified, -> { where(notified_at: nil) }
end
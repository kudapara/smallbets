class UnreadMentionsNotifierJob < ApplicationJob
  def perform
    User.active.administrator.subscribed("notifications").find_each do |user|
      log "Checking for unread mentions...", user

      begin
        unread_messages = user.memberships.visible.unread.includes(:room, unread_notifications: :creator)
                              .flat_map { |m| m.unread_notifications.joins(:mentions).where(mentions: { notified_at: nil }) }
        unread_messages.reject! { |m| m.created_at < 7.days.ago }

        next if unread_messages.empty?

        # Require at least one mention older than 12 hours to notify user
        next unless unread_messages.any? { |m| m.created_at <= 12.hours.ago }

        log "Found #{unread_messages.count} mentions to notify about.", user

        unread_messages.sort_by!(&:created_at)

        NotifierMailer.unread_mentions(user, unread_messages).deliver_now
        user.mentions.where(message_id: unread_messages.map(&:id)).update_all(notified_at: Time.current)

        log "Notified about #{unread_messages.count} unread mentions.", user
      rescue => e
        log "Failed to notify about unread mentions: #{e.message}", user
      end
    end

    log "Done notifying all users."
  end

  private

  def log(message, user = nil)
    "[UnreadMentionsNotifierJob]#{"[#{user.id}]" if user.present?} #{message}"
  end
end

module Message::Broadcasts
  def broadcast_create
    broadcast_append_to room, :messages, target: [ room, :messages ], partial: "messages/message", locals: { current_room: room }
    ActionCable.server.broadcast("unread_rooms", { roomId: room.id })

    broadcast_notifications
  end

  def broadcast_update
    broadcast_notifications(ignore_if_older_message: true)
  end
  
  def broadcast_notifications(ignore_if_older_message: false)
    memberships = room.memberships.where(user_id: mentionee_ids)
    memberships = memberships.or(room.memberships.involved_in_everything)

    memberships.each do |membership|
      next if ignore_if_older_message && (membership.read? || membership.unread_at > created_at)

      ActionCable.server.broadcast "user_#{membership.user_id}_notifications", { roomId: room.id }
    end
  end
end

module Threads::Broadcasts
  def broadcast_update_message_involvements(message)
    message.mentionees.including(message.creator).each do |user|
      refresh_shared_rooms(user)
    end
  end

  def refresh_shared_rooms(user)
    memberships = user.memberships.visible.without_expired_threads.with_ordered_room
    thread_memberships = memberships.select { |membership| membership.room.thread? }.sort_by { |m| m.room.created_at }
    memberships = memberships.without(thread_memberships).reject { |membership| membership.room.direct? }

    user.broadcast_replace_to user, :rooms, target: :shared_rooms,
                              partial: "users/sidebars/rooms/shared_rooms_list",
                              locals: { memberships: memberships, thread_memberships: thread_memberships },
                              attributes: { maintain_scroll: true }
  end
end
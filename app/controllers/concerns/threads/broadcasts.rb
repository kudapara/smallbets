module Threads::Broadcasts
  def broadcast_update_message_involvements(message)
    message.mentionees.including(message.creator).each do |user|
      refresh_shared_rooms(user)
    end
  end

  def refresh_shared_rooms(user)
    memberships = user.memberships.visible.without_direct_rooms.without_expired_threads
    thread_memberships = memberships.select { |membership| membership.room.thread? }.sort_by { |m| m.room.created_at }
    memberships = memberships.without(thread_memberships)

    {
      inbox: memberships.with_room_by_last_active_oldest_first,
      starred_rooms: memberships.with_room_by_sort_preference(Current.user.preference("starred_rooms_sort_order")),
      shared_rooms: memberships.with_room_by_sort_preference(Current.user.preference("all_rooms_sort_order"))
    }.each do |list_name, memberships|
      user.broadcast_replace_to user, :rooms, target: list_name,
                                partial: "users/sidebars/rooms/shared_rooms_list",
                                locals: { list_name:, memberships:, thread_memberships: },
                                attributes: { maintain_scroll: true }
    end
  end
end
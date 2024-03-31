module Threads::Broadcasts
  def broadcast_update_parent_room(membership)
    return unless membership
    
    user = membership.user
    parent_room = membership.room.top_level_parent_room
    parent_membership = parent_room.memberships.find_by(user: user)

    # Broadcast append in case user did not have the parent room in the list of rooms. If duplicate, this will be ignored.
    parent_room.broadcast_append_to user, :rooms, target: :shared_rooms,
                                     partial: "users/sidebars/rooms/shared_with_threads",
                                     locals: { membership: parent_membership, thread_memberships: user.memberships.visible.thread_rooms }
    
    # Broadcast update in case user had the parent room in the list of rooms
    parent_room.broadcast_replace_to user, :rooms, target: [ parent_room, :list_node ],
                                     partial: "users/sidebars/rooms/shared_with_threads",
                                     locals: { membership: parent_membership, thread_memberships: user.memberships.visible.thread_rooms }
  end

  def broadcast_update_message_involvements(message)
    message.mentionees.including(message.creator).each do |user|
      broadcast_update_parent_room(message.room.memberships.find_by(user: user))
    end
  end
end
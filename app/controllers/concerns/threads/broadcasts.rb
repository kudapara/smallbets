module Threads::Broadcasts
  def broadcast_update_parent_room(membership)
    user = membership.user
    parent_room = membership.room.top_level_parent_room
    parent_membership = parent_room.memberships.find_by(user: user)
    
    parent_room.broadcast_replace_to user, :rooms, target: [ parent_room, :list_node ],
                                     partial: "users/sidebars/rooms/shared_with_threads",
                                     locals: { membership: parent_membership, thread_memberships: user.memberships.visible.thread_rooms }
  end
end
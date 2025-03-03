class Users::SidebarsController < ApplicationController
  DIRECT_PLACEHOLDERS = 10

  def show
    # Step 1: Load memberships with unread notifications
    memberships = Current.user.memberships.visible.without_thread_rooms.with_has_unread_notifications.includes(:room)
    
    # Step 2: Extract direct memberships with messages
    @direct_memberships = extract_direct_memberships_with_messages
    
    # Step 3: Process other memberships
    # Since we're now using a separate query for direct memberships, we need to get non-direct memberships differently
    other_memberships = Current.user.memberships
                               .visible
                               .without_thread_rooms
                               .with_has_unread_notifications
                               .includes(:room)
                               .joins(:room)
                               .where.not(rooms: { type: "Rooms::Direct" })
    
    @all_memberships = other_memberships.with_room_by_sort_preference(Current.user.preference("all_rooms_sort_order"))
    @starred_memberships = other_memberships.with_room_by_last_active_newest_first
    
    # Step 4: Find direct placeholder users
    @direct_placeholder_users = find_direct_placeholder_users
  end

  private
    # Method that combines extracting direct memberships and filtering for messages_count > 0
    def extract_direct_memberships_with_messages
      Current.user.memberships
             .visible
             .without_thread_rooms
             .with_has_unread_notifications
             .includes(:room)
             .joins(:room)
             .where(rooms: { type: "Rooms::Direct" })
             .where("rooms.messages_count > 0")
             .order("rooms.updated_at DESC")
    end

    def find_direct_placeholder_users
      exclude_user_ids = Membership.active
                         .joins("JOIN rooms ON memberships.room_id = rooms.id")
                         .where(rooms: { type: "Rooms::Direct" })
                         .where("rooms.id IN (SELECT room_id FROM memberships WHERE user_id = ? AND active = TRUE)", Current.user.id)
                         .pluck(:user_id)
                         .uniq
                         .push(Current.user.id)
      
      User.active.where.not(id: exclude_user_ids).order(:created_at).limit([ DIRECT_PLACEHOLDERS - exclude_user_ids.count, 0 ].max)
    end
end

module Sidebar
  extend ActiveSupport::Concern

  included do
    helper_method :for_each_sidebar_section
  end

  def set_sidebar_memberships
    memberships = Current.user.memberships.visible.without_thread_rooms
                          .joins(:room).where(rooms: { active: true })
                          .with_has_unread_notifications
                          .includes(:room)
                          .with_room_by_last_active_newest_first

    # Get all direct memberships and filter them
    all_direct_memberships = memberships.select { |m| m.room.direct? }
    filtered_direct = filter_direct_memberships(all_direct_memberships)

    # Only keep direct rooms with messages, but preserve all for virtual scrolling
    @direct_memberships = filtered_direct.select { |m| m.room.messages_count > 0 }

    # Get other memberships using the without_direct_rooms scope
    other_memberships = Current.user.memberships.visible.without_thread_rooms
                                   .without_direct_rooms.joins(:room)
                                   .where(rooms: { active: true })
                                   .with_has_unread_notifications
                                   .includes(:room)

    # For virtual scrolling, we keep all memberships but may render only first 30
    # The view will handle the actual limiting and virtual scrolling
    @all_memberships = other_memberships
    @starred_memberships = other_memberships
  end

  def for_each_sidebar_section
    [ :starred_rooms, :shared_rooms ].each do |name|
      yield name
    end
  end

  private

  def filter_direct_memberships(direct_memberships)
    # Filter direct memberships to only include:
    # 1. Memberships with unread messages
    # 2. Memberships updated in the last 7 days
    direct_memberships.select do |membership|
      membership.unread? ||
        membership.has_unread_notifications? ||
        (membership.room.updated_at.present? && membership.room.updated_at >= 7.days.ago)
    end.sort_by { |m| m.room.updated_at || Time.at(0) }.reverse
  end
end

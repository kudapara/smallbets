module SidebarHelper
  def inbox_sort_order
    sort_by_last_updated_newest_first
  end

  def all_rooms_sort_order
    sort_by_user_preference Current.user.preference("all_rooms_sort_order")
  end

  def sort_by_user_preference(preference)
    case preference
    when "alphabetical"
      sort_alphabetically
    when "most_active"
      sort_by_most_active
    else
      sort_by_last_updated_newest_first
    end
  end

  def sort_by_most_active
    raw "data-sorted-list-attribute-value='size' data-sorted-list-attribute-type-value='number' data-sorted-list-order-value='desc'"
  end

  def sort_by_last_updated_newest_first
    raw "data-sorted-list-attribute-value='updatedAt' data-sorted-list-order-value='desc'"
  end

  def sort_alphabetically
    raw "data-sorted-list-attribute-value='name'"
  end
  
  def cache_sidebar_room(section, membership, thread_memberships)
    if thread_memberships.any? { |m| m.room.parent_room&.id == membership.room_id }
      yield # do not cache memberships with threads - little upside
    else
      cache(sidebar_membership_cache_key(section, membership)) do
        yield
      end
    end
  end

  def sidebar_membership_cache_key(prefix, membership)
    [ prefix, membership.room, membership.involvement, membership.unread?, membership.has_unread_notifications? ]
  end
end

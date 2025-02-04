module SidebarHelper
  def inbox_sort_order
    sort_by_last_updated_newest_first
  end

  def starred_rooms_sort_order
    sort_by_user_preference Current.user.preference("starred_rooms_sort_order")
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

  def sort_by_last_updated_oldest_first
    raw "data-sorted-list-attribute-value='updatedAt'"
  end

  def sort_by_last_updated_newest_first
    raw "data-sorted-list-attribute-value='updatedAt' data-sorted-list-order-value='desc'"
  end

  def sort_alphabetically
    raw "data-sorted-list-attribute-value='name'"
  end
end

module SidebarHelper
  def inbox_sort_order
    sort_by_last_updated_oldest_first
  end

  def all_rooms_sort_order
    case Current.user.preference("all_rooms_sort_order")
    when "alphabetical"
      sort_alphabetically
    when "last_updated"
      sort_by_last_updated_newest_first
    else
      sort_by_most_active
    end
  end

  def sort_by_most_active
    raw "data-sorted-list-attribute-value='size' data-sorted-list-attribute-type-value='number' data-sorted-list-order-value='desc'"
  end
  
  def sort_by_last_updated_oldest_first
    raw "data-sorted-list-attribute-value='updatedAt' data-sorted-list-attribute-type-value='number'"
  end

  def sort_by_last_updated_newest_first
    raw "data-sorted-list-attribute-value='updatedAt' data-sorted-list-attribute-type-value='number' data-sorted-list-order-value='desc'"
  end

  def sort_alphabetically
    raw "data-sorted-list-attribute-value='name'"
  end
end

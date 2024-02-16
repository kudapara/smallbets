class Autocompletable::UsersController < ApplicationController
  def index
    set_page_and_extract_portion_from find_autocompletable_users.with_attached_avatar.ordered, per_page: 20
  end

  private
    def find_autocompletable_users
      params[:query].present? ? users_scope.active.filtered_by(params[:query]) : users_scope.active
    end

    def users_scope
      params[:room_id].present? ? Current.user.rooms.find(params[:room_id]).users : User.all
    end
end

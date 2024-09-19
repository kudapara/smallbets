class Autocompletable::UsersController < ApplicationController
  def index
    set_page_and_extract_portion_from find_autocompletable_users.with_attached_avatar, per_page: 20
  end

  private
    def find_autocompletable_users
      users_scope.active.without_default_names.filtered_by(params[:query])
    end

    def users_scope
      scope = params[:room_id].present? ? Current.user.rooms.find(params[:room_id]).users : User.all
      scope.recent_posters_first(params[:room_id])
    end
end

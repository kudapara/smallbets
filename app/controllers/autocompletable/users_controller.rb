class Autocompletable::UsersController < ApplicationController
  def index
    @users = find_autocompletable_users
  end

  private
    def find_autocompletable_users
      exact_name_matches = users_scope.by_first_name(params[:query])
      all_matches = users_scope.filtered_by(params[:query]).limit(20)

      (all_matches + exact_name_matches).uniq
    end

    def users_scope
      scope = params[:room_id].present? ? Current.user.rooms.find(params[:room_id]).users : User.all
      scope.active.without_default_names.recent_posters_first(params[:room_id]).with_attached_avatar
    end
end

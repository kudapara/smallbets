class Rooms::Directs::ByBotsController < Rooms::DirectsController
  rescue_from Exception, with: :respond_with_error
  allow_bot_access only: :create

  def create
    create_room
    render json: { room: { id: @room.id } }, status: (@room.previously_new_record? ? :created : :ok)
  end

  private
  def selected_users
    # Current user is a bot without sso_user_id
    User.where(sso_user_id: sso_user_ids).or(User.where(id: Current.user.id))
  end

  def sso_user_ids
    params.fetch(:users, [])
  end
  
  def respond_with_error(error)
    render json: { error: error.message }, status: :internal_server_error
  end
end

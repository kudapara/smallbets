class Rooms::Threads::ByBotsController < Rooms::ThreadsController
  rescue_from Exception, with: :respond_with_error
  allow_bot_access only: :create

  def create
    create_room
    render json: { room: { id: @room.id } }, status: :ok
  end

  private
  def room_params
    params.permit(:name, :parent_message_id)
  end

  def set_parent_message
    @parent_message = Message.joins(:room).where.not(room: { type: "Rooms::Direct" }).find(params[:parent_message_id])
  end
  
  def respond_with_error(error)
    render json: { error: error.message }, status: :internal_server_error
  end
end

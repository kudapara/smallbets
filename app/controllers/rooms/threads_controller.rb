class Rooms::ThreadsController < RoomsController
  before_action :set_parent_message, only: %i[ create ]
  
  DEFAULT_ROOM_NAME = "New thread"

  def create
    @room = Rooms::Thread.create_for(room_params, users: parent_room.users)
    @room.update(name: room_params[:name])

    broadcast_create_room
    broadcast_update_parent_message
    redirect_to room_url(@room) if request.format.html?
  end

  def edit
  end

  def update
    @room.update! room_params

    broadcast_update_room
    broadcast_update_parent_message
    redirect_to room_url(@room)
  end
  
  private
  def set_parent_message
    if message = Current.user.reachable_messages.find_by(id: params[:parent_message_id])
      @parent_message = message
    else
      redirect_to root_url, alert: "Message not found or inaccessible"
    end
  end
  
  def parent_room
    @parent_message.room
  end

  def room_params
    params.require(:room).permit(:name)
  end

  def broadcast_create_room
    each_user_and_html_for(@room) do |user, html|
      broadcast_append_to user, :rooms, target: :shared_rooms, html: html
    end
  end

  def broadcast_update_room
    each_user_and_html_for(@room) do |user, html|
      broadcast_replace_to user, :rooms, target: [ @room, :list ], html: html
    end
  end

  def each_user_and_html_for(room)
    # Optimization to avoid rendering the same partial for every user
    unread_html = render_to_string(partial: "users/sidebars/rooms/shared", locals: { room: room, unread: true })
    read_html = render_to_string(partial: "users/sidebars/rooms/shared", locals: { room: room, unread: false })

    room.memberships.visible.each do |membership|
      yield membership.user, membership.unread? ? unread_html : read_html
    end
  end
end

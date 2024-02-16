class Rooms::OpensController < RoomsController
  before_action :force_room_type, only: %i[ edit update ]

  DEFAULT_ROOM_NAME = "New room"

  def show
    redirect_to room_url(@room)
  end

  def new
    @room = Rooms::Open.new(name: DEFAULT_ROOM_NAME)
    @users = User.active.ordered
  end

  def create
    room = Rooms::Open.create_for(room_params, users: Current.user)

    broadcast_create_room(room)
    redirect_to room_url(room)
  end

  def edit
    @users = User.active.ordered
  end

  def update
    @room.update! room_params

    broadcast_update_room
    redirect_to room_url(@room)
  end

  private
    # Allows us to edit a closed room and turn it into an open one on saving.
    def force_room_type
      @room = @room.becomes!(Rooms::Open)
    end

    def broadcast_create_room(room)
      broadcast_prepend_to :rooms, target: :shared_rooms, partial: "users/sidebars/rooms/shared", locals: { room: room }
    end

    def broadcast_update_room
      broadcast_replace_to :rooms, target: [ @room, :list ], partial: "users/sidebars/rooms/shared", locals: { room: @room }
    end
end

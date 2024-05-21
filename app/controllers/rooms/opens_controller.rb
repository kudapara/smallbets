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
    @room = Rooms::Open.create_for(room_params, users: Current.user)

    broadcast_create_room
    redirect_to room_url(@room)
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

    def broadcast_create_room
      broadcast_append_to :rooms, target: :shared_rooms, partial: "users/sidebars/rooms/shared", locals: { room: @room }, attributes: { maintain_scroll: true }
    end

    def broadcast_update_room
      each_user_and_html_for(@room) do | user, html |
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

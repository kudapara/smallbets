class Rooms::ThreadsController < RoomsController
  include Threads::Broadcasts
  
  before_action :set_parent_message, only: %i[ new create ]
  
  DEFAULT_ROOM_NAME = "New thread"

  def new
    @room = @parent_message.threads.new(name: DEFAULT_ROOM_NAME)
  end
  
  def create
    create_room
    redirect_to room_url(@room)
  end

  def edit
    @users = @room.visible_users.active.includes(avatar_attachment: :blob).ordered
  end

  def update
    @room.update! room_params

    broadcast_update_room
    broadcast_update_parent_message
    redirect_to room_url(@room)
  end

  def destroy
    deactivate_room
    redirect_to room_at_message_path(@room.parent_message.room, @room.parent_message)
  end
  
  private
  def create_room
    @room = Rooms::Thread.create_for(room_params.merge(parent_message_id: @parent_message&.id), users: parent_room.users)

    broadcast_create_room
    broadcast_update_parent_message
  end
  
  def set_parent_message
    if message = Current.user.reachable_messages.joins(:room).where.not(room: { type: "Rooms::Direct" }).find_by(id: params[:parent_message_id])
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
    @room.memberships.visible.each do |membership|
      refresh_shared_rooms(membership.user)
    end
  end

  def broadcast_update_room
    for_each_sidebar_section do |list_name|
      each_user_and_html_for(@room, list_name:) do |user, html|
        broadcast_replace_to user, :rooms, target: [@room, helpers.dom_prefix(list_name, :node_content)], html: html
      end
    end
  end

  def each_user_and_html_for(room, **locals)
    html_cache = {}

    room.memberships.visible.includes(:user).with_has_unread_notifications.each do |membership|
      yield membership.user, render_or_cached(html_cache,
                                              partial: "users/sidebars/rooms/shared",
                                              locals: { room: room,
                                                        involvement: membership.involvement,
                                                        unread: membership.unread?,
                                                        has_notifications: membership.preloaded_has_unread_notifications?}.merge(locals))
    end
  end
end

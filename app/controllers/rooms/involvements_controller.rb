class Rooms::InvolvementsController < ApplicationController
  include RoomScoped, Threads::Broadcasts

  def show
    @involvement = @membership.involvement
  end

  def update
    @membership.update! involvement: params[:involvement]

    broadcast_visibility_changes
    redirect_to room_involvement_url(@room)
  end

  private
    def broadcast_visibility_changes
      case
      when @room.direct?
        # Do nothing
      when @membership.involved_in_invisible?
        broadcast_remove_to @membership.user, :rooms, target: [ @room, :list_node ]
      when @membership.involvement_previously_was.inquiry.invisible?
        if @room.thread?
          broadcast_update_parent_room(@membership)
        else
          broadcast_append_to @membership.user, :rooms, target: :shared_rooms, partial: "users/sidebars/rooms/shared", locals: { room: @room }
        end
      end
    end
end

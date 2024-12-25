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
        [:inbox, :shared_rooms].each do |list_name|
          broadcast_remove_to @membership.user, :rooms, target: [@room, helpers.dom_prefix(list_name, :list_node)]
        end
      when @membership.involvement_previously_was.inquiry.invisible?
        if @room.thread?
          refresh_shared_rooms(@membership.user)
        else
          [:inbox, :shared_rooms].each do |list_name|
            broadcast_append_to @membership.user, :rooms, target: list_name, 
                                partial: "users/sidebars/rooms/shared_with_threads", locals: { list_name:, membership: @membership }, 
                                attributes: { maintain_scroll: true }
          end
        end
      end
    end
end

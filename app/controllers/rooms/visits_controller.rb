class Rooms::VisitsController < ApplicationController
  include RoomScoped

  before_action :remember_last_room_visited

  def create
    head :created
  end
end

module Message::Broadcasts
  def broadcast_create
    broadcast_append_to room, :messages, target: [ room, :messages ], partial: "messages/message", locals: { current_room: room }
    ActionCable.server.broadcast("unread_rooms", { roomId: room.id })
  end
end

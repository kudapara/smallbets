import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "room" ]

  connect() {
    this.initialRoomTargets = new Set(this.roomTargets)
    this.toggleRooms()
  }

  roomTargetConnected(element) {
    if (this.initialRoomTargets && !this.initialRoomTargets.has(element)) {
      this.toggleRooms()
    }
  }

  toggleRooms() {
    this.roomTargets.forEach((room) => {
      const involvement = room.dataset.involvement
      const isUnread = room.querySelector(".unread") !== null
      const hasBadge = room.querySelector(".badge") !== null
      
      const isVisible =
          (involvement === "everything" && isUnread) ||
          (isUnread && hasBadge)
      
      if (isVisible) {
        room.removeAttribute("hidden")
        this.#showParentRooms(room)
      } else {
        room.setAttribute("hidden", true)
      }
    })
  }

  #showParentRooms(room) {
    let parentRoom = room.closest("[data-type='list_node']")?.parentElement.closest("[data-type='list_node']")

    while (parentRoom) {
      parentRoom.removeAttribute("hidden")
      parentRoom = parentRoom.parentElement.closest("[data-type='list_node']")
    }
  }
}

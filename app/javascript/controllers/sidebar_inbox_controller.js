import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "room", "emptySpace" ]

  connect() {
    this.toggleRooms()
  }

  roomTargetConnected(element) {
    this.#toggleRoom(element)
    this.#toggleEmptySpace()
  }

  roomTargetDisconnected(element) {
    this.#toggleEmptySpace()
  }

  toggleRooms() {
    this.roomTargets.forEach((room) => {
      this.#toggleRoom(room)
    })
    this.#toggleEmptySpace()
  }
  
  #toggleRoom(room) {
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
  }

  #toggleEmptySpace() {
    const hasVisibleRoom = this.roomTargets.some(room => !room.hasAttribute("hidden"))

    if (hasVisibleRoom) {
      this.emptySpaceTarget.setAttribute("hidden", true)
    } else {
      this.emptySpaceTarget.removeAttribute("hidden")
    }
  }

  #showParentRooms(room) {
    let parentRoom = room.parentElement.closest("[data-sidebar-starred-rooms-target='room']")

    while (parentRoom) {
      parentRoom.removeAttribute("hidden")
      parentRoom = parentRoom.parentElement.closest("[data-sidebar-inbox-target='room']")
    }
  }
}

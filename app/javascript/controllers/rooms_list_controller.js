import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"
import { ignoringBriefDisconnects } from "helpers/dom_helpers"

export default class extends Controller {
  static targets = [ "room" ]
  static classes = [ "unread", "badge" ]

  #disconnected = true

  async connect() {
    this.unreadsChannel ??= await cable.subscribeTo({ channel: "UnreadRoomsChannel" }, {
      connected: this.#channelConnected.bind(this),
      disconnected: this.#channelDisconnected.bind(this),
      received: this.#unread.bind(this)
    })
    this.userUnreadsChannel ??= await cable.subscribeTo({ channel: "UserUnreadRoomsChannel" }, {
      received: this.#unread.bind(this)
    })
    this.notificationsChannel ??= await cable.subscribeTo({ channel: "UnreadNotificationsChannel" }, {
      received: this.#addBadge.bind(this)
    })
  }

  disconnect() {
    ignoringBriefDisconnects(this.element, () => {
      this.unreadsChannel?.unsubscribe()
      this.unreadsChannel = null

      this.userUnreadsChannel?.unsubscribe()
      this.userUnreadsChannel = null

      this.notificationsChannel?.unsubscribe()
      this.notificationsChannel = null
    })
  }

  loaded() {
    this.read({ detail: { roomId: Current.room.id } })
  }

  read({ detail: { roomId } }) {
    const room = this.#findRoomTarget(roomId)

    if (room) {
      room.classList.remove(this.unreadClass, this.badgeClass)
      this.dispatch("read", { detail: { targetId: roomId } })
    }
  }

  #channelConnected() {
    if (this.#disconnected) {
      this.#disconnected = false
      this.element.reload()
    }
  }

  #channelDisconnected() {
    this.#disconnected = true
  }

  #unread({ roomId }) {
    const unreadRoom = this.#findRoomTarget(roomId)

    if (unreadRoom) {
      if (Current.room.id != roomId) {
        unreadRoom.classList.add(this.unreadClass)
      }

      this.dispatch("unread", { detail: { targetId: unreadRoom.id } })
    }
  }

  #addBadge({ roomId }) {
    const unreadRoom = this.#findRoomTarget(roomId)

    if (unreadRoom) {
      if (Current.room.id != roomId) {
        unreadRoom.classList.add(this.badgeClass)
      }
    }
  }

  #findRoomTarget(roomId) {
    return this.roomTargets.find(roomTarget => roomTarget.dataset.roomId == roomId)
  }
}

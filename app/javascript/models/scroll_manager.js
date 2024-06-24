import { onNextEventLoopTick } from "helpers/timing_helpers"

const AUTO_SCROLL_THRESHOLD = 100

export default class ScrollManager {
  static #pendingOperations = Promise.resolve()

  #container

  constructor(container) {
    this.#container = container
  }

  async autoscroll(forceScroll, render = () => {}) {
    return this.#appendOperation(async () => {
      const wasNearEnd = this.#scrolledNearEnd

      await render()

      if (wasNearEnd || forceScroll) {
        this.#container.scrollTop = this.#container.scrollHeight
        return true
      } else {
        return false
      }
    })
  }

  async keepScroll(top, render, scrollBehaviour, delay) {
    return this.#appendOperation(async () => {
      const scrollTop = this.#container.scrollTop
      const scrollHeight = this.#container.scrollHeight

      await render()

      const newScrollTop = top ? scrollTop + (this.#container.scrollHeight - scrollHeight) : scrollTop
      
      if (delay) {
        onNextEventLoopTick(() => this.#container.scrollTo({ top: newScrollTop, behavior: scrollBehaviour }))
      } else {
        this.#container.scrollTo({ top: newScrollTop, behavior: scrollBehaviour })
      }
    })
  }

  // Private

  #appendOperation(operation) {
    ScrollManager.#pendingOperations =
      ScrollManager.#pendingOperations.then(operation)
    return ScrollManager.#pendingOperations
  }

  get #scrolledNearEnd() {
    return this.#distanceScrolledFromEnd <= AUTO_SCROLL_THRESHOLD
  }

  get #distanceScrolledFromEnd() {
    return this.#container.scrollHeight - this.#container.scrollTop - this.#container.clientHeight
  }
}

import { get } from "@rails/request.js"
import {
  insertHTMLFragment,
  parseHTMLFragment,
  keepScroll,
  trimChildren,
} from "helpers/dom_helpers"
import { ThreadStyle } from "models/message_formatter"
import ScrollTracker from "models/scroll_tracker"

const MAX_MESSAGES = 300
const MAX_MESSAGES_LEEWAY = 20

export default class MessagePaginator {
  #container
  #url
  #messageFormatter
  #allContentViewedCallback
  #scrollTracker
  #upToDate = true

  constructor(container, url, messageFormatter, allContentViewedCallback) {
    this.#container = container
    this.#url = url
    this.#messageFormatter = messageFormatter
    this.#allContentViewedCallback = allContentViewedCallback
    this.#scrollTracker = new ScrollTracker(container, { lastChildRevealed: this.#messageBecameVisible.bind(this) })
  }


  // API

  monitor() {
    this.#scrollTracker.connect()
  }

  disconnect() {
    this.#scrollTracker.disconnect()
  }

  get upToDate() {
    return this.#upToDate
  }

  set upToDate(value) {
    this.#upToDate = value
  }

  async resetToLastPage() {
    this.upToDate = true
    await this.#showLastPage()
  }

  async trimExcessMessages(top) {
    const overage = this.#container.children.length - MAX_MESSAGES
    if (overage > MAX_MESSAGES_LEEWAY) {
      trimChildren(overage, this.#container, top)
      if (!top) {
        this.upToDate = false
      }
    }
  }

  // Internal

  #messageBecameVisible(element) {
    const messageId = element.dataset.messageId
    console.log('message became visible ' + messageId)
    const firstMesage = element === this.#container.firstElementChild
    const lastMessage = element === this.#container.lastElementChild

    if (messageId) {
      if (firstMesage) {
        this.#addPage({ before: messageId }, true)
      }
      if (lastMessage && !this.upToDate) {
        console.log('will add page')
        this.#addPage({ after: messageId }, false)
      }
      if (lastMessage && this.upToDate) {
        console.log('all viewed')
        this.#allContentViewedCallback?.()
      }
    }
  }

  async #showLastPage() {
    const resp = await this.#fetchPage()
    if (resp.statusCode === 200) {
      const page = await this.#formatPage(resp)
      this.#container.replaceChildren(page)
    }
  }

  async #addPage(params, top) {
    const resp = await this.#fetchPage(params)

    if (resp.statusCode === 204 && !top) {
      this.upToDate = true
      this.#allContentViewedCallback?.()
    }

    if (resp.statusCode === 200) {
      const page = await this.#formatPage(resp)
      const lastNewElement = page.lastElementChild

      keepScroll(this.#container, top, () => {
        insertHTMLFragment(page, this.#container, top)

        // Ensure formatting is correct over page boundaries
        if (top && lastNewElement?.nextElementSibling) {
          this.#messageFormatter.format(lastNewElement.nextElementSibling, ThreadStyle.thread)
        }
      })

      this.trimExcessMessages(!top)
    }
  }

  async #fetchPage(params) {
    const url = new URL(this.#url)
    for (const param in params) {
      url.searchParams.set(param, params[param])
    }

    return await get(url)
  }

  async #formatPage(response) {
    const text = await response.html
    const fragment = parseHTMLFragment(text)

    for (const message of fragment.querySelectorAll(".message")) {
      this.#messageFormatter.format(message, ThreadStyle.thread)
    }

    return fragment
  }
}

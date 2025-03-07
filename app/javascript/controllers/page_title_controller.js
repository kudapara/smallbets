import { Controller } from "@hotwired/stimulus"
import { onNextEventLoopTick } from "helpers/timing_helpers"

export default class extends Controller {
  static values = {
    originalTitle: String
  }

  connect() {
    // Bind the event handlers once to maintain the same reference
    this.boundUpdateTitle = this.updateTitle.bind(this)
    this.boundCheckTitle = this.checkTitle.bind(this)
    
    // Store the original page title when the controller connects
    this.originalTitleValue = document.title
    
    // Listen for unread and badge events from rooms-list
    window.addEventListener("rooms-list:unread", this.boundUpdateTitle)
    window.addEventListener("rooms-list:read", this.boundUpdateTitle)
    window.addEventListener("rooms-list:addBadge", this.boundUpdateTitle)
    
    // Listen for Turbo navigation events
    document.addEventListener("turbo:before-render", this.boundCheckTitle)
    
    // Initial update
    onNextEventLoopTick(this.boundUpdateTitle)
  }

  disconnect() {
    // Clean up event listeners
    window.removeEventListener("rooms-list:unread", this.boundUpdateTitle)
    window.removeEventListener("rooms-list:read", this.boundUpdateTitle)
    window.removeEventListener("rooms-list:addBadge", this.boundUpdateTitle)
    
    // Clean up Turbo navigation event listeners
    document.removeEventListener("turbo:before-render", this.boundCheckTitle)
    
    // Restore original title
    document.title = this.originalTitleValue
  }
  
  // Check if the title has changed
  checkTitle() {
    const currentTitle = document.title
    
    // If the title has changed and doesn't have our indicators, update our stored value
    if (currentTitle !== this.originalTitleValue && 
        !currentTitle.startsWith('🔴') && 
        !currentTitle.startsWith('⚫')) {
      this.originalTitleValue = currentTitle
      this.updateTitle()
    }
  }

  updateTitle() {
    // First check for any dot conditions
    const hasDot = this.#checkForAnyDot()
    
    // Then check if it should be a red dot
    const hasRedDot = hasDot && this.#checkForRedDot()
    
    // Update the title with appropriate indicator
    if (hasRedDot) {
      document.title = `🔴 ${this.originalTitleValue}`
    } else if (hasDot) {
      document.title = `⚫ ${this.originalTitleValue}`
    } else {
      document.title = this.originalTitleValue
    }
  }
  
  #checkForAnyDot() {
    const hasStarredUnread = document.querySelector("#starred_rooms [data-type=list_node]:not([hidden]) .unread") !== null
    const hasDirectUnread = document.querySelector(".direct.unread") !== null
    
    return hasStarredUnread || hasDirectUnread
  }
  
  #checkForRedDot() {
    const hasDirectUnread = document.querySelector(".direct.unread") !== null
    
    return hasDirectUnread
  }
} 
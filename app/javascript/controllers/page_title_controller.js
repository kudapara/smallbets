import { Controller } from "@hotwired/stimulus"
import { onNextEventLoopTick } from "helpers/timing_helpers"

export default class extends Controller {
  static values = {
    originalTitle: String
  }

  connect() {
    // Store the original page title when the controller connects
    this.originalTitleValue = document.title
    
    // Bind the event handlers once to maintain the same reference
    this.boundUpdateTitle = this.updateTitle.bind(this)
    
    // Listen for unread and badge events from rooms-list
    window.addEventListener("rooms-list:unread", this.boundUpdateTitle)
    window.addEventListener("rooms-list:read", this.boundUpdateTitle)
    window.addEventListener("rooms-list:addBadge", this.boundUpdateTitle)
    window.addEventListener("rooms-list:involved", this.boundUpdateTitle)
    window.addEventListener("rooms-list:renamed", this.boundUpdateTitle)
    
    // Also update when visibility changes (tab becomes visible again)
    document.addEventListener("visibilitychange", this.boundUpdateTitle)
    
    // Initial update
    onNextEventLoopTick(() => this.updateTitle())
  }

  disconnect() {
    // Clean up event listeners
    window.removeEventListener("rooms-list:unread", this.boundUpdateTitle)
    window.removeEventListener("rooms-list:read", this.boundUpdateTitle)
    window.removeEventListener("rooms-list:addBadge", this.boundUpdateTitle)
    window.removeEventListener("rooms-list:involved", this.boundUpdateTitle)
    window.removeEventListener("rooms-list:renamed", this.boundUpdateTitle)
    document.removeEventListener("visibilitychange", this.boundUpdateTitle)
    
    // Restore original title
    document.title = this.originalTitleValue
  }

  updateTitle() {
    // Get the real sidebar toggle button
    const sidebarToggle = document.querySelector(".sidebar__toggle")
    if (!sidebarToggle) {
      return
    }
    
    // First check for any dot conditions
    const hasDot = this.#checkForAnyDot()
    
    // Then check if it should be a red dot
    const hasRedDot = hasDot && this.#checkForRedDot()
    
    // Update the title with appropriate indicator
    if (hasRedDot) {
      // Red dot for mentions
      document.title = `🔴 ${this.originalTitleValue}`
    } else if (hasDot) {
      // Black dot for unread messages
      document.title = `⚫ ${this.originalTitleValue}`
    } else {
      // No indicator
      document.title = this.originalTitleValue
    }
  }
  
  // Check if the hamburger menu has any dot (black or red)
  #checkForAnyDot() {
    // This matches the CSS selector from sidebar.css (but without the :not(.open) part):
    // #sidebar:has(#sidebar_inbox [data-type=list_node]:not([hidden]), #starred_rooms [data-type=list_node]:not([hidden]) .unread, .direct.unread)
    
    // Check for unread inbox items
    const hasInboxItems = document.querySelector("#sidebar_inbox [data-type=list_node]:not([hidden])") !== null
    
    // Check for unread starred rooms
    const hasStarredUnread = document.querySelector("#starred_rooms [data-type=list_node]:not([hidden]) .unread") !== null
    
    // Check for unread direct messages
    const hasDirectUnread = document.querySelector(".direct.unread") !== null
    
    return hasInboxItems || hasStarredUnread || hasDirectUnread
  }
  
  // Check if the hamburger menu has a red dot
  #checkForRedDot() {
    // This matches the CSS selector from sidebar.css (but without the :not(.open) part):
    // #sidebar:has(#sidebar_inbox [data-type=list_node]:not([hidden]), .direct.unread)
    
    // Check for unread inbox items
    const hasInboxItems = document.querySelector("#sidebar_inbox [data-type=list_node]:not([hidden])") !== null
    
    // Check for unread direct messages
    const hasDirectUnread = document.querySelector(".direct.unread") !== null
    
    return hasInboxItems || hasDirectUnread
  }
} 
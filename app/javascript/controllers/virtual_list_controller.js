import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["template", "container"]
    static values = { 
        itemHeight: { type: Number, default: 32 },
        batchSize: { type: Number, default: 20 },
        rootMargin: { type: String, default: "0px 0px 20px 0px" }  // Only 20px bottom margin
    }
    
    connect() {
        this.isLoading = false
        this.renderedCount = this.element.querySelectorAll('[data-type="list_node"]').length
    }

    templateTargetConnected() {
        this.templateElement = this.templateTarget
        this.setupIntersectionObserver()
    }
    
    disconnect() {
        if (this.observer) {
            this.observer.disconnect()
        }
        if (this.scrollContainer && this.scrollHandler) {
            this.scrollContainer.removeEventListener('scroll', this.scrollHandler)
        }
    }
    
    handleScroll() {
        if (this.isLoading || !this.sentinel || !this.scrollContainer) return
        
        const scrollTop = this.scrollContainer.scrollTop
        const scrollHeight = this.scrollContainer.scrollHeight
        const clientHeight = this.scrollContainer.clientHeight
        const scrollBottom = scrollTop + clientHeight
        const threshold = 20 // pixels from bottom
        
        if (scrollHeight - scrollBottom < threshold && !this.isLoading) {
            this.loadMoreRooms()
        }
    }
    
    checkSentinelVisibility() {
        if (!this.sentinel) return
        
        const scrollContainer = this.element.closest('.sidebar__container')
        if (!scrollContainer) return
        
        const containerRect = scrollContainer.getBoundingClientRect()
        const sentinelRect = this.sentinel.getBoundingClientRect()
        
        // If sentinel is visible and we have items to load, trigger loading
        if (sentinelRect.top <= containerRect.bottom && !this.isLoading) {
            this.loadMoreRooms()
        }
    }
    
    setupIntersectionObserver() {
        // Create and observe a sentinel element at the bottom
        this.sentinel = document.createElement('div')
        this.sentinel.className = 'virtual-list-sentinel'
        this.sentinel.style.height = '1px'
        this.sentinel.setAttribute('aria-hidden', 'true')
        this.element.appendChild(this.sentinel)
        
        // Find the scrolling container (sidebar__container)
        this.scrollContainer = this.element.closest('.sidebar__container') || 
                               this.element.closest('.overflow-y') ||
                               this.element.closest('[data-controller*="maintain-scroll"]')
        
        // Set up intersection observer
        this.observer = new IntersectionObserver(
            entries => this.handleIntersection(entries),
            { 
                root: this.scrollContainer,
                rootMargin: this.rootMarginValue,
                threshold: [0, 0.1, 0.5, 1.0]
            }
        )
        
        this.observer.observe(this.sentinel)
        
        // Also add scroll listener as fallback
        if (this.scrollContainer) {
            this.scrollHandler = this.handleScroll.bind(this)
            this.scrollContainer.addEventListener('scroll', this.scrollHandler, { passive: true })
        }
    }
    
    handleIntersection(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting && !this.isLoading) {
                this.loadMoreRooms()
            }
        })
    }
    
    async loadMoreRooms() {
        if (!this.templateElement || this.isLoading) return
        
        this.isLoading = true
        
        try {
            // Get next batch of rooms from template
            const templateChildren = Array.from(this.templateElement.content.children)
            const nextBatch = templateChildren.slice(0, this.batchSizeValue)
            
            if (nextBatch.length === 0) {
                // No more items to load, remove sentinel
                if (this.sentinel) {
                    this.sentinel.remove()
                }
                if (this.observer) {
                    this.observer.disconnect()
                }
                return
            }
            
            // Create a document fragment for better performance
            const fragment = document.createDocumentFragment()
            
            nextBatch.forEach(roomData => {
                const roomHtml = this.renderRoom(roomData.dataset)
                const temp = document.createElement('div')
                temp.innerHTML = roomHtml
                const roomElement = temp.firstElementChild
                
                // Apply initial visibility based on involvement for starred rooms
                if (this.element.id === 'starred_rooms') {
                    const involvement = roomData.dataset.involvement
                    if (involvement !== 'everything') {
                        roomElement.setAttribute('hidden', true)
                    }
                }
                
                fragment.appendChild(roomElement)
                
                // Remove from template after rendering
                roomData.remove()
            })
            
            // Insert all new rooms at once before sentinel
            if (this.sentinel && this.sentinel.parentNode) {
                this.element.insertBefore(fragment, this.sentinel)
            } else {
                this.element.appendChild(fragment)
            }
            
            this.renderedCount += nextBatch.length
            
            // Trigger any necessary events for newly added rooms
            this.dispatch('roomsLoaded', { 
                detail: { 
                    count: nextBatch.length, 
                    total: this.renderedCount 
                } 
            })
            
            // Trigger sorted-list to re-sort if it exists
            const sortedListController = this.element.closest('[data-controller*="sorted-list"]')
            if (sortedListController) {
                // Dispatch an event that sorted-list can listen to
                sortedListController.dispatchEvent(new CustomEvent('virtual-list:items-added', {
                    bubbles: true,
                    detail: { count: nextBatch.length }
                }))
            }
            
        } finally {
            // Allow loading again after a short delay
            setTimeout(() => {
                this.isLoading = false
            }, 100)
        }
    }
    
    renderRoom(data) {
        const domId = data.domId
        const roomId = data.roomId
        const membershipRoomId = data.membershipRoomId
        const roomName = data.roomName || 'Room'
        const sortableName = data.sortableName || roomName.toLowerCase()
        const roomPath = data.roomPath || '#'
        const membershipId = data.membershipId
        const isUnread = data.unread === 'true'
        const hasNotifications = data.hasNotifications === 'true'
        const isDirect = data.direct === 'true'
        const involvement = data.involvement || 'mentions'
        const involvementImagePath = data.involvementImagePath || '/assets/notification-bell-mentions.svg'
        const messagesCount = data.messagesCount || '0'
        const lastActiveAt = data.lastActiveAt
        const lastActiveRelative = data.lastActiveRelative
        const listName = data.listName || 'all_rooms'
        
        // Build the room link classes
        const linkClasses = [
            'flex', 'flex-item-grow', 'gap', 'align-center', 
            'justify-space-between', 'room', 'full-height', 
            'txt-nowrap', 'overflow-ellipsis', 'txt-lighter', 
            'txt-undecorated', 'pad-block', 'position-relative'
        ]
        if (isUnread) linkClasses.push('unread')
        if (hasNotifications) linkClasses.push('badge')
        
        // Use the pre-rendered relative time from Rails or format it
        const dateHtml = lastActiveRelative ? 
            lastActiveRelative.replace(/&quot;/g, '"') : 
            (lastActiveAt ? `<time datetime="${lastActiveAt}" class="txt-x-small txt-primary txt-nowrap position-relative">${this.formatRelativeTime(lastActiveAt)}</time>` : '')
        
        // Render involvement button based on involvement type
        const involvementIcon = this.getInvolvementIcon(involvement)
        const involvementLabel = this.getInvolvementLabel(involvement)
        
        // Render the room item matching the existing structure exactly
        return `
            <div id="${domId}" 
                 data-sorted-list-target="item"
                 data-name="${sortableName}"
                 data-search-text="${sortableName}"
                 data-size="${messagesCount}"
                 data-updated-at="${lastActiveAt || ''}"
                 data-sidebar-starred-rooms-target="room"
                 data-involvement="${involvement}"
                 data-type="list_node"
                 class="flex gap align-center justify-space-between">
                <a href="${roomPath}" 
                   class="${linkClasses.join(' ')}"
                   style="padding-block: calc(var(--block-space) / 4);"
                   data-turbo-frame="_top">
                    <span class="overflow-ellipsis">${this.escapeHtml(roomName)}</span>
                    <hr class="separator flex-item-grow" aria-hidden="true">
                    ${dateHtml}
                </a>
                <span class="txt-small">
                    <turbo-frame id="sidebar_involvement_${roomId}">
                        <form class="button_to" method="post" action="/rooms/${membershipRoomId}/involvement?from_sidebar=true&involvement=${this.getNextInvolvement(involvement, isDirect)}">
                            <input type="hidden" name="_method" value="put" autocomplete="off">
                            <input type="hidden" name="authenticity_token" value="${this.getCSRFToken()}" autocomplete="off">
                            <button type="submit" role="checkbox" aria-checked="true" aria-labelledby="${roomId}_involvement_label" tabindex="0" class="btn ${involvement}">
                                <img aria-hidden="true" src="${involvementImagePath}" width="20" height="20">
                                <span class="for-screen-reader" id="${roomId}_involvement_label">${involvementLabel}</span>
                            </button>
                        </form>
                    </turbo-frame>
                </span>
            </div>
        `
    }
    
    getInvolvementIcon(involvement) {
        return `notification-bell-${involvement}.svg`
    }
    
    getInvolvementLabel(involvement) {
        const labels = {
            'mentions': 'Room in All Rooms',
            'everything': 'Room in My Rooms',
            'invisible': 'Room hidden from sidebar'
        }
        return labels[involvement] || 'Room in All Rooms'
    }
    
    getNextInvolvement(currentInvolvement, isDirect) {
        if (isDirect) {
            // For direct rooms: everything -> nothing -> everything
            return currentInvolvement === 'everything' ? 'nothing' : 'everything'
        } else {
            // For shared rooms in sidebar: mentions -> everything -> mentions
            return currentInvolvement === 'mentions' ? 'everything' : 'mentions'
        }
    }
    
    formatRelativeTime(isoString) {
        // Simple relative time formatting - can be enhanced
        const date = new Date(isoString)
        const now = new Date()
        const diffMs = now - date
        const diffMins = Math.floor(diffMs / 60000)
        const diffHours = Math.floor(diffMs / 3600000)
        const diffDays = Math.floor(diffMs / 86400000)
        
        if (diffMins < 1) return 'now'
        if (diffMins < 60) return `${diffMins}m`
        if (diffHours < 24) return `${diffHours}h`
        if (diffDays < 7) return `${diffDays}d`
        return date.toLocaleDateString()
    }
    
    escapeHtml(text) {
        const div = document.createElement('div')
        div.textContent = text
        return div.innerHTML
    }
    
    getCSRFToken() {
        const metaTag = document.querySelector('meta[name="csrf-token"]')
        return metaTag ? metaTag.getAttribute('content') : ''
    }
}
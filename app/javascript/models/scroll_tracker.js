const SCROLLED_AWAY_FROM_LATEST_THRESHOLD = 500

export default class ScrollTracker {
    #container
    #lastChildRevealedCallback
    #scrolledFarFromLatestCallback
    #intersectionObserver
    #mutationObserver
    #firstChildWasHidden

    constructor(container, { lastChildRevealed, scrolledFarFromLatest }) {
        this.#container = container
        this.#lastChildRevealedCallback = lastChildRevealed
        this.#scrolledFarFromLatestCallback = scrolledFarFromLatest

        this.#mutationObserver = new MutationObserver(this.#childrenChanged.bind(this))
        this.#mutationObserver.observe(container, {childList: true})

        if (this.#lastChildRevealedCallback) {
            this.#intersectionObserver = new IntersectionObserver(this.#handleIntersection.bind(this), {root: container})
        }

        if (this.#scrolledFarFromLatestCallback) {
            this.#container.addEventListener('scroll', this.#onScroll.bind(this));
        }
    }

    connect() {
        this.#childrenChanged()
    }

    disconnect() {
        this.#intersectionObserver?.disconnect()
    }

    #childrenChanged() {
        this.disconnect()

        if (this.#container.firstElementChild) {
            this.#firstChildWasHidden = false

            this.#intersectionObserver?.observe(this.#container.firstElementChild)
            this.#intersectionObserver?.observe(this.#container.lastElementChild)
        }
    }

    #handleIntersection(entries) {
        for (const entry of entries) {
            // Don't callback when the first child is shown, unless it had previously
            // been hidden. This avoids the issue that adding new pages will always
            // fire the callback for the first item before the scroll position is
            // adjusted.
            //
            // We don't do this with the last item, because it's possible that
            // fetching a page could return less than a screenfull.
            const isFirst = entry.target === this.#container.firstElementChild
            const significantReveal = (isFirst && this.#firstChildWasHidden) || !isFirst

            if (entry.isIntersecting) {
                if (significantReveal) {
                    this.#lastChildRevealedCallback(entry.target)
                }
            } else {
                if (isFirst) {
                    this.#firstChildWasHidden = true
                }
            }
        }
    }

    #onScroll() {
        if (this.scrolledFarFromLatest) {
            this.#scrolledFarFromLatestCallback?.()
        }
    }

    get scrolledFarFromLatest() {
        return this.#distanceScrolledFromEnd > SCROLLED_AWAY_FROM_LATEST_THRESHOLD
    }

    get #distanceScrolledFromEnd() {
        return this.#container.scrollHeight - this.#container.scrollTop - this.#container.clientHeight
    }
}
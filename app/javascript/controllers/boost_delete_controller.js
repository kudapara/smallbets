import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "reveal", "perform" ]

  reveal({ srcElement, params: { boosterId } }) {
    // Can't rely on regular event.stopPropagation as it's needed for Turbo
    if (srcElement.closest('[data-stop-propagation]')) return;
    
    if (Current.user.id === boosterId) {
      this.element.classList.toggle(this.revealClass)
    }
  }

  perform() {
    this.element.classList.add(this.performClass)
  }
}

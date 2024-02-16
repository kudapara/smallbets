import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "reveal", "perform" ]

  reveal({ params: { boosterId } }) {
    if (Current.user.id === boosterId) {
      this.element.classList.toggle(this.revealClass)
    }
  }

  perform() {
    this.element.classList.add(this.performClass)
  }
}

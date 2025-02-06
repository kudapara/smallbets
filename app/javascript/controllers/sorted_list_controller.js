import { Controller } from "@hotwired/stimulus"
import { debounce, throttle } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item", "container" ]
  static values = {
    attribute: String,
    attributeType: String,
    order: String,
  }

  initialize() {
    this.sortKey = this.attributeValue || 'name'
    this.sortKeyType = this.attributeTypeValue || 'string'
    this.sortOrder = this.orderValue || 'asc'
  }

  itemTargetConnected(target) {
    if (this.isSorting) return
    
    this.#scheduledSort()
  }
  
  reSort() {
    this.#throttledSort()
  }

  sort() {
    if (this.isSorting) return
    this.isSorting = true

    const container = this.hasContainerTarget ? this.containerTarget : this.element
    
    const sortCriteria = [
      { key: 'sortedListPriority', type: 'number', order: 'asc' },
      { key: this.sortKey, type: this.sortKeyType, order: this.sortOrder },
    ]

    this.itemTargets
        .sort((a, b) => this.#compareItems(a, b, sortCriteria))
        .forEach(item => { container.appendChild(item) })

    setTimeout(() => { this.isSorting = false }, 100)
  }

  #compareItems(a, b, criteria) {
    for (const { key, type, order } of criteria) {
      const aVal = a.dataset[key],
            bVal = b.dataset[key]

      if (aVal == null && bVal == null) continue
      if (aVal == null) return 1
      if (bVal == null) return -1

      let comparison = 0
      if (type === 'number') {
        comparison = parseFloat(aVal) - parseFloat(bVal)
      } else if (type === 'string') {
        comparison = aVal.localeCompare(bVal)
      }

      if (comparison !== 0) {
        return order === 'asc' ? comparison : -comparison
      }
    }
    
    return 0
  }

  #throttledSort = throttle(this.sort.bind(this))
  #scheduledSort = debounce(this.sort.bind(this), 300)
}

import { Controller } from "@hotwired/stimulus"
import { throttle } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item" ]

  itemTargetConnected(target) {
    this.#throttledSort()
  }

  moveToFront({ detail: { targetId }}) {
    this.#updateItemAndSort(targetId, "0")
  }

  updateItem({ detail: { targetId }}) {
    this.#updateItemAndSort(targetId, "1")
  }

  #updateItemAndSort(targetId, priority) {
    const itemTargetForUpdate = this.itemTargets.find(itemTarget => itemTarget.id == targetId)

    if (itemTargetForUpdate) {
      itemTargetForUpdate.dataset.sortedListPriority = priority

      if (itemTargetForUpdate.dataset.sortedListNumber) {
        itemTargetForUpdate.dataset.sortedListNumber = new Date().getTime()
      }

      this.sort()
    }
  }

  sort() {
    const sortCriteria = [
      { key: 'sortedListPriority', type: 'number', order: 'asc' },
      { key: 'sortedListNumber', type: 'number', order: 'desc' },
      { key: 'sortedListName', type: 'string', order: 'asc' },
    ]

    this.itemTargets
        .sort((a, b) => this.#compareItems(a, b, sortCriteria))
        .forEach(item => this.element.appendChild(item))
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
}

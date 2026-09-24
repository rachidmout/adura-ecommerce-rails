import { Controller } from "@hotwired/stimulus"

export default class CartQuantityController extends Controller {
  static targets = ["select", "decrement", "increment"]

  connect() {
    this.sync()
  }

  decrement() {
    this.changeBy(-1)
  }

  increment() {
    this.changeBy(1)
  }

  sync() {
    this.decrementTarget.disabled = this.selectTarget.selectedIndex === 0
    this.incrementTarget.disabled = this.selectTarget.selectedIndex === this.selectTarget.options.length - 1
  }

  changeBy(amount) {
    const index = this.selectTarget.selectedIndex + amount
    if (index < 0 || index >= this.selectTarget.options.length) return

    this.selectTarget.selectedIndex = index
    this.sync()
    this.element.requestSubmit()
  }
}

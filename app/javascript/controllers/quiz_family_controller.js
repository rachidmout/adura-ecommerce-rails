import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "option"]

  connect() {
    this.sync()
  }

  select() {
    this.sync()
  }

  sync() {
    this.optionTargets.forEach((option) => {
      const input = option.querySelector("input[type='radio']")
      option.classList.toggle("is-selected", input?.checked)
    })
  }
}

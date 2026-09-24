import { Controller } from "@hotwired/stimulus"

export default class CheckoutSubmissionController extends Controller {
  static targets = ["submit"]
  static values = { submittingLabel: String }

  submit(event) {
    if (this.submitting) {
      event.preventDefault()
      return
    }

    this.submitting = true
    this.submitTargets.forEach((button) => {
      button.disabled = true
      button.setAttribute("aria-disabled", "true")
      button.textContent = this.submittingLabelValue
    })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class FilterPanelController extends Controller {
  static targets = ["toggle"]

  connect() {
    this.mobileQuery = window.matchMedia("(max-width: 640px)")
    this.handleBreakpointChange = this.sync.bind(this)
    this.mobileQuery.addEventListener("change", this.handleBreakpointChange)
    this.sync()
  }

  disconnect() {
    this.mobileQuery.removeEventListener("change", this.handleBreakpointChange)
  }

  toggle() {
    if (this.mobileQuery.matches) this.setOpen(!this.element.classList.contains("is-open"))
  }

  sync() {
    this.element.classList.add("filters-ready")
    this.setOpen(!this.mobileQuery.matches)
  }

  setOpen(open) {
    this.element.classList.toggle("is-open", open)
    this.toggleTarget.setAttribute("aria-expanded", String(open))
  }
}

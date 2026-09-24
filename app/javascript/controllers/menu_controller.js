import { Controller } from "@hotwired/stimulus"

export default class MenuController extends Controller {
  static targets = ["navigation", "button", "backdrop"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.closeBeforeTurboCache = this.closeBeforeTurboCache.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    document.addEventListener("turbo:before-cache", this.closeBeforeTurboCache)
    this.setOpen(false)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("turbo:before-cache", this.closeBeforeTurboCache)
  }

  toggle(event) {
    event.preventDefault()

    const open = !this.isOpen
    this.setOpen(open)
    if (open && event.detail === 0) this.navigationTarget.querySelector("a")?.focus()
  }

  close() {
    this.setOpen(false)
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.close()
      this.buttonTarget.focus()
    }
  }

  closeBeforeTurboCache() {
    this.close()
  }

  get isOpen() {
    return this.navigationTarget.classList.contains("is-open")
  }

  setOpen(open) {
    this.navigationTarget.classList.toggle("is-open", open)
    this.backdropTarget.hidden = !open
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    this.buttonTarget.classList.toggle("is-open", open)
  }
}

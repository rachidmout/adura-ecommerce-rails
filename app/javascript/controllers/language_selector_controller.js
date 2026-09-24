import { Controller } from "@hotwired/stimulus"

// Petit menu déroulant accessible : un bouton "trigger" qui affiche/cache un
// menu de liens. Contrairement à un <select> natif, chaque option est un
// vrai lien (<a href>), donc changer de langue est juste une navigation
// normale — pas besoin de gérer un état de sélection en JS.
export default class LanguageSelectorController extends Controller {
  static targets = ["trigger", "menu"]

  connect() {
    this.onClickOutside = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.onKeydown = (event) => {
      if (event.key === "Escape") this.close()
    }
  }

  disconnect() {
    this.close()
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.element.classList.add("is-open")
    this.triggerTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.onClickOutside)
    document.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.element.classList.remove("is-open")
    this.triggerTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.onClickOutside)
    document.removeEventListener("keydown", this.onKeydown)
  }

  get isOpen() {
    return this.element.classList.contains("is-open")
  }
}

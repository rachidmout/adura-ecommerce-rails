import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["country", "postalCode", "city", "choices", "status"]
  static values = {
    url: String,
    autofilledMessage: String,
    searchingMessage: String,
    notFoundMessage: String,
    multipleMessage: String,
    placeholder: String
  }

  connect() {
    this.lookupTimer = null
  }

  disconnect() {
    clearTimeout(this.lookupTimer)
  }

  countryChanged() {
    this.clearChoices()
    if (this.cityTarget.dataset.addressLookupAutofilled === "true") this.cityTarget.value = ""
    delete this.cityTarget.dataset.addressLookupAutofilled
    this.statusTarget.textContent = ""
    this.lookupIfReady()
  }

  postalCodeChanged() {
    this.clearChoices()
    this.statusTarget.textContent = ""
    clearTimeout(this.lookupTimer)
    this.lookupTimer = setTimeout(() => this.lookupIfReady(), 250)
  }

  citySelected() {
    const city = this.choicesTarget.value
    if (!city) return

    this.cityTarget.value = city
    this.cityTarget.dataset.addressLookupAutofilled = "true"
    this.cityTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.statusTarget.textContent = this.autofilledMessageValue
  }

  async lookupIfReady() {
    if (this.countryTarget.value !== "FR" || !/^\d{5}$/.test(this.postalCodeTarget.value)) return

    this.statusTarget.textContent = this.searchingMessageValue
    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("country_code", this.countryTarget.value)
      url.searchParams.set("postal_code", this.postalCodeTarget.value)
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const data = await response.json()
      this.showCities(data.cities || [])
    } catch (_) {
      this.clearChoices()
      this.statusTarget.textContent = this.notFoundMessageValue
    }
  }

  showCities(cities) {
    this.clearChoices()
    if (cities.length === 1) {
      this.cityTarget.value = cities[0]
      this.cityTarget.dataset.addressLookupAutofilled = "true"
      this.cityTarget.dispatchEvent(new Event("input", { bubbles: true }))
      this.statusTarget.textContent = this.autofilledMessageValue
    } else if (cities.length > 1) {
      cities.forEach((city) => this.choicesTarget.add(new Option(city, city)))
      this.choicesTarget.hidden = false
      this.statusTarget.textContent = this.multipleMessageValue
    } else {
      this.statusTarget.textContent = this.notFoundMessageValue
    }
  }

  clearChoices() {
    this.choicesTarget.replaceChildren(new Option(this.placeholderValue, ""))
    this.choicesTarget.hidden = true
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "status", "searchButton", "results", "selectedId", "selection", "selectedDetails"]
  static values = {
    searchUrl: String,
    searchingMessage: String,
    selectMethodMessage: String,
    chooseAnotherMessage: String,
    searchAgainLabel: String,
    addressChangedMessage: String,
    unavailableMessage: String,
    chooseLabel: String
  }

  connect() {
    this.points = new Map()
    const selectedMethod = this.element.querySelector("input[name='shipping_method_id']:checked")
    if (selectedMethod) this.shippingMethodChanged({ detail: { shippingMethodId: selectedMethod.value, kind: selectedMethod.dataset.shippingMethodsKind } })
  }

  shippingMethodChanged({ detail }) {
    this.shippingMethodId = detail.shippingMethodId
    this.pickupPointRequired = detail.kind === "pickup_point"
    this.clearSelection({ announce: false })
    this.sectionTarget.hidden = !this.pickupPointRequired
    if (this.pickupPointRequired) this.statusTarget.textContent = this.selectMethodMessageValue
  }

  addressChanged() {
    if (!this.selectedIdTarget.value) return

    this.clearSelection({ announce: true })
    this.statusTarget.textContent = this.addressChangedMessageValue
  }

  async search() {
    const country = this.fieldValue("order[country_code]")
    const postalCode = this.fieldValue("order[postal_code]")
    const city = this.fieldValue("order[city]")
    if (!this.shippingMethodId || !country || !postalCode || !city) {
      this.statusTarget.textContent = this.selectMethodMessageValue
      return
    }

    this.searchButtonTarget.disabled = true
    this.statusTarget.textContent = this.searchingMessageValue
    this.resultsTarget.replaceChildren()
    try {
      const url = new URL(this.searchUrlValue, window.location.origin)
      url.searchParams.set("shipping_method_id", this.shippingMethodId)
      url.searchParams.set("country_code", country)
      url.searchParams.set("postal_code", postalCode)
      url.searchParams.set("city", city)
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || this.unavailableMessageValue)

      this.points = new Map(data.points.map((point) => [point.relay_id, point]))
      data.points.forEach((point) => this.resultsTarget.append(this.pointCard(point)))
      this.statusTarget.textContent = data.points.length ? "" : (data.message || this.unavailableMessageValue)
    } catch (error) {
      this.statusTarget.textContent = error.message || this.unavailableMessageValue
    } finally {
      this.searchButtonTarget.disabled = false
    }
  }

  choose(event) {
    const point = this.points.get(event.currentTarget.dataset.relayId)
    if (!point) return

    this.selectedIdTarget.value = point.relay_id
    this.selectedDetailsTarget.replaceChildren(this.pointDetails(point))
    this.resultsTarget.replaceChildren()
    this.selectionTarget.hidden = false
    this.statusTarget.textContent = ""
    this.dispatch("selected")
  }

  change() {
    const points = Array.from(this.points.values())
    this.clearSelection({ announce: false, preservePoints: true })
    this.searchButtonTarget.textContent = this.searchAgainLabelValue
    points.forEach((point) => this.resultsTarget.append(this.pointCard(point)))
    this.statusTarget.textContent = points.length ? this.chooseAnotherMessageValue : this.selectMethodMessageValue
    const firstChoice = this.resultsTarget.querySelector("button[data-action='pickup-point#choose']")
    if (firstChoice) {
      firstChoice.focus()
    } else {
      this.searchButtonTarget.focus()
    }
  }

  clearSelection({ announce, preservePoints = false }) {
    this.selectedIdTarget.value = ""
    this.selectionTarget.hidden = true
    this.resultsTarget.replaceChildren()
    if (!preservePoints) this.points = new Map()
    if (announce || this.pickupPointRequired) this.dispatch("cleared")
  }

  pointCard(point) {
    const card = document.createElement("article")
    card.className = "pickup-point-card"
    card.append(this.pointDetails(point))
    const button = document.createElement("button")
    button.type = "button"
    button.className = "button button-secondary"
    button.dataset.action = "pickup-point#choose"
    button.dataset.relayId = point.relay_id
    button.textContent = this.chooseLabelValue
    card.append(button)
    return card
  }

  pointDetails(point) {
    const details = document.createElement("div")
    details.className = "pickup-point-details"
    const name = document.createElement("strong")
    name.className = "pickup-point-details__name"
    name.textContent = point.name
    const address = document.createElement("span")
    address.className = "pickup-point-details__address"
    address.textContent = [point.address_line1, point.address_line2, `${point.postal_code} ${point.city}`].filter(Boolean).join(", ")
    details.append(name, address)
    const meta = document.createElement("div")
    meta.className = "pickup-point-details__meta"
    if (point.distance_km) {
      const distance = document.createElement("small")
      distance.textContent = `${point.distance_km} km`
      meta.append(distance)
    }
    if (point.opening_hours) {
      const hours = document.createElement("small")
      hours.textContent = point.opening_hours
      meta.append(hours)
    }
    if (meta.childElementCount) details.append(meta)
    return details
  }

  fieldValue(name) {
    return this.element.querySelector(`[name='${name}']`)?.value?.trim()
  }
}

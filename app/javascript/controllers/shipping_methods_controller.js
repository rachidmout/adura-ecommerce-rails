import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["options", "status", "shippingAmount", "totalAmount", "stickyTotal", "submit", "desktopSubmit", "stickySubmit"]
  static values = {
    url: String,
    subtotalCents: Number,
    discountCents: Number,
    countryRequiredMessage: String,
    payCtaTemplate: String,
    stickyPayCtaTemplate: String,
    refreshingMessage: String,
    chooseMessage: String,
    noneMessage: String,
    unavailableMessage: String,
    freeLabel: String,
    toSelectLabel: String,
    currencyLocale: String
  }

  connect() {
    this.country = document.querySelector("[name='order[country_code]']")
    this.country?.addEventListener("change", this.refresh)
  }

  disconnect() {
    this.country?.removeEventListener("change", this.refresh)
  }

  refresh = async () => {
    this.optionsTarget.replaceChildren()
    this.clearTotals()
    this.setSubmitEnabled(false)
    if (!this.country?.value) {
      this.statusTarget.textContent = this.countryRequiredMessageValue
      return
    }
    this.statusTarget.textContent = this.refreshingMessageValue
    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("country_code", this.country.value)
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const data = await response.json()
      if (!response.ok) {
        this.statusTarget.textContent = data.error
        this.clearTotals()
        return
      }
      this.subtotalCentsValue = data.subtotal_cents
      this.discountCentsValue = data.discount_cents
      data.methods.forEach((method) => this.optionsTarget.append(this.option(method)))
      this.statusTarget.textContent = data.methods.length ? this.chooseMessageValue : this.noneMessageValue
      this.clearTotals()
    } catch (_) {
      this.optionsTarget.replaceChildren()
      this.statusTarget.textContent = this.unavailableMessageValue
      this.clearTotals()
    }
  }

  select(event) {
    const input = event.currentTarget
    const priceCents = Number(input.dataset.shippingMethodsPriceCents)
    const pickupPoint = input.dataset.shippingMethodsKind === "pickup_point"
    this.shippingAmountTarget.textContent = priceCents === 0 ? this.freeLabelValue : this.money(priceCents)
    const total = this.subtotalCentsValue + priceCents - this.discountCentsValue
    this.totalAmountTarget.textContent = this.money(total)
    this.stickyTotalTarget.textContent = this.money(total)
    this.updatePaymentButtonLabels(total)
    this.setSubmitEnabled(!pickupPoint)
    this.dispatch("selected", { detail: { shippingMethodId: input.value, kind: input.dataset.shippingMethodsKind } })
  }

  pickupPointSelected() {
    const selected = this.optionsTarget.querySelector("input[name='shipping_method_id']:checked")
    if (selected?.dataset.shippingMethodsKind === "pickup_point") this.setSubmitEnabled(true)
  }

  pickupPointCleared() {
    const selected = this.optionsTarget.querySelector("input[name='shipping_method_id']:checked")
    if (selected?.dataset.shippingMethodsKind === "pickup_point") this.setSubmitEnabled(false)
  }

  option(method) {
    const label = document.createElement("label")
    label.className = "shipping-method-card"
    const input = document.createElement("input")
    input.type = "radio"
    input.name = "shipping_method_id"
    input.value = method.shipping_method_id
    input.dataset.action = "change->shipping-methods#select ecommerce-analytics#selectShippingMethod"
    input.dataset.shippingMethodsPriceCents = method.price_cents
    input.dataset.shippingMethodsKind = method.kind
    input.dataset.ecommerceAnalyticsShippingMethod = JSON.stringify({
      shipping_tier: [ method.name, method.carrier_name ].filter(Boolean).join(" — "),
      price: method.price_cents / 100
    })
    const details = document.createElement("span")
    const name = document.createElement("strong")
    name.textContent = method.name
    const carrier = document.createElement("small")
    carrier.textContent = method.carrier_name
    details.append(name, carrier)
    const price = document.createElement("b")
    price.textContent = method.free_shipping ? this.freeLabelValue : this.money(method.price_cents)
    label.append(input, details, price)
    return label
  }

  clearTotals() {
    this.shippingAmountTarget.textContent = this.toSelectLabelValue
    this.totalAmountTarget.textContent = "—"
    this.stickyTotalTarget.textContent = "—"
    this.updatePaymentButtonLabels()
  }

  updatePaymentButtonLabels(totalCents = null) {
    const amount = totalCents === null ? "—" : this.money(totalCents)
    this.desktopSubmitTargets.forEach((button) => {
      button.textContent = this.payCtaTemplateValue.replace("__amount__", amount)
    })
    this.stickySubmitTargets.forEach((button) => {
      button.textContent = this.stickyPayCtaTemplateValue.replace("__amount__", amount)
    })
  }

  setSubmitEnabled(enabled) {
    this.submitTargets.forEach((button) => {
      button.disabled = !enabled
      button.setAttribute("aria-disabled", String(!enabled))
    })
  }

  money(amountCents) {
    return new Intl.NumberFormat(this.currencyLocaleValue, { style: "currency", currency: "EUR" }).format(amountCents / 100)
  }
}

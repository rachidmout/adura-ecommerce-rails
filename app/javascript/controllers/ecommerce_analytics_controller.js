import { Controller } from "@hotwired/stimulus"
import { analyticsConsent, trackAnalyticsEvent } from "analytics"

// Ce contrôleur est le seul point de branchement des événements ecommerce.
// Les payloads sont préparés par Rails dans les attributs data, sans aucune
// donnée client ni code promo saisi.
export default class extends Controller {
  static values = { viewItem: Object, viewCart: Object, beginCheckout: Object, promo: Object, purchase: Object }

  connect() {
    this.trackInitial("view_item", this.hasViewItemValue ? this.viewItemValue : null)
    this.trackInitial("view_cart", this.hasViewCartValue ? this.viewCartValue : null)
    this.trackInitial("begin_checkout", this.hasBeginCheckoutValue ? this.beginCheckoutValue : null)
    this.trackInitial("apply_promo", this.hasPromoValue ? this.promoValue : null)
    this.trackPurchase()
  }

  selectVariant(event) {
    const item = this.jsonFrom(event.currentTarget.dataset.ecommerceAnalyticsItem)
    if (!item || item.item_id === this.selectedItemId) return

    this.selectedItemId = item.item_id
    this.track("select_variant", this.itemEvent(item))
  }

  addToCart(event) {
    const form = event.currentTarget
    const variantId = form.querySelector("[name='variant_id']")?.value
    const item = this.itemForVariant(variantId)
    const quantity = Number(form.querySelector("[name='quantity']")?.value || 1)
    if (!item || !Number.isFinite(quantity) || quantity < 1) return

    item.quantity = quantity
    this.track("add_to_cart", this.itemEvent(item, quantity))
  }

  removeFromCart(event) {
    const item = this.jsonFrom(event.currentTarget.dataset.ecommerceAnalyticsItem)
    if (!item) return

    this.track("remove_from_cart", this.itemEvent(item, item.quantity))
  }

  selectShippingMethod(event) {
    const shipping = this.jsonFrom(event.currentTarget.dataset.ecommerceAnalyticsShippingMethod)
    if (!shipping) return

    const items = this.hasBeginCheckoutValue ? this.beginCheckoutValue.items : []
    this.track("select_shipping_method", {
      currency: "EUR",
      value: shipping.price,
      shipping_tier: shipping.shipping_tier,
      items
    })
  }

  trackInitial(name, payload) {
    if (!payload) return

    this.track(name, payload, `${name}:${window.location.pathname}`)
  }

  trackPurchase() {
    if (!this.hasPurchaseValue) return
    if (analyticsConsent() !== true) return

    const transactionId = this.purchaseValue.transaction_id
    if (!transactionId || this.purchaseAlreadyTracked(transactionId)) return

    if (this.track("purchase", this.purchaseValue, `purchase:${transactionId}`)) {
      this.rememberPurchase(transactionId)
    }
  }

  track(name, payload, dedupeKey) {
    return trackAnalyticsEvent(name, payload, { dedupeKey })
  }

  itemEvent(item, quantity = 1) {
    const normalizedItem = { ...item, quantity }
    return {
      currency: "EUR",
      value: Number((Number(normalizedItem.price) * quantity).toFixed(2)),
      items: [ normalizedItem ]
    }
  }

  itemForVariant(variantId) {
    const element = Array.from(this.element.querySelectorAll("[data-ecommerce-analytics-item]"))
      .find((candidate) => candidate.dataset.variantId === variantId)
    return this.jsonFrom(element?.dataset.ecommerceAnalyticsItem)
  }

  jsonFrom(value) {
    if (!value) return null

    try {
      return JSON.parse(value)
    } catch {
      return null
    }
  }

  purchaseStorageKey(transactionId) {
    return `adura_purchase_tracked_${transactionId}`
  }

  purchaseAlreadyTracked(transactionId) {
    try {
      return window.localStorage.getItem(this.purchaseStorageKey(transactionId)) === "1"
    } catch {
      return false
    }
  }

  rememberPurchase(transactionId) {
    try {
      window.localStorage.setItem(this.purchaseStorageKey(transactionId), "1")
    } catch {
      // transaction_id reste la déduplication GA4 de secours.
    }
  }
}

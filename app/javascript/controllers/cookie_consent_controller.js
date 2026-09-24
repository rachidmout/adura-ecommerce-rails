import { Controller } from "@hotwired/stimulus"
import { analyticsConsent, initializeAnalytics, saveAnalyticsConsent } from "analytics"

export default class extends Controller {
  static targets = ["banner", "preferences", "analytics", "preferencesTrigger"]

  connect() {
    initializeAnalytics()

    if (analyticsConsent() === null) {
      this.showBanner()
    } else {
      this.hideBanner()
    }
  }

  accept() {
    this.persist(true)
  }

  reject() {
    this.persist(false)
  }

  save(event) {
    event.preventDefault()
    this.persist(this.analyticsTarget.checked)
  }

  openPreferences() {
    this.showBanner()
    this.preferencesTarget.hidden = false
    this.analyticsTarget.checked = analyticsConsent() === true
    this.preferencesTriggerTargets.forEach((trigger) => trigger.setAttribute("aria-expanded", "true"))
    this.analyticsTarget.focus()
  }

  closePreferences() {
    this.preferencesTarget.hidden = true
    this.preferencesTriggerTargets.forEach((trigger) => trigger.setAttribute("aria-expanded", "false"))
    if (analyticsConsent() !== null) this.hideBanner()
  }

  showBanner() {
    this.bannerTarget.hidden = false
  }

  hideBanner() {
    this.bannerTarget.hidden = true
    this.preferencesTarget.hidden = true
    this.preferencesTriggerTargets.forEach((trigger) => trigger.setAttribute("aria-expanded", "false"))
  }

  persist(analytics) {
    saveAnalyticsConsent(analytics)
    this.hideBanner()
  }
}

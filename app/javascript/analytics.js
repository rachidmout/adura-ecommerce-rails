const CONSENT_STORAGE_KEY = "adura.analytics_consent.v1"

let configuredMeasurementId
let loading = false
let googleTagReady = false
let pendingPageView
let pendingEvents = []
let lastPageViewLocation
let consentOverride
let consentModeInitialized = false
const sentEventKeys = new Set()
const pendingEventKeys = new Set()

export function initializeAnalytics() {
  const measurementId = configuredMeasurementId || measurementIdFromPage()
  if (!measurementId) return

  initializeConsentMode()
  enableAnalyticsIfConsented(measurementId)
}

export function analyticsConsent() {
  if (consentOverride !== undefined) return consentOverride

  try {
    const preference = JSON.parse(window.localStorage.getItem(CONSENT_STORAGE_KEY))
    return typeof preference?.analytics === "boolean" ? preference.analytics : null
  } catch {
    return null
  }
}

export function saveAnalyticsConsent(analytics) {
  const preference = { analytics: Boolean(analytics), version: 1 }
  consentOverride = preference.analytics

  try {
    window.localStorage.setItem(CONSENT_STORAGE_KEY, JSON.stringify(preference))
  } catch {
    // Sans stockage navigateur, le choix reste valable pour la page en cours.
  }

  initializeConsentMode()
  window.gtag("consent", "update", consentState(preference.analytics))

  if (preference.analytics) {
    enableAnalyticsIfConsented(measurementIdFromPage())
    trackPageView()
  } else {
    pendingPageView = undefined
    pendingEvents = []
    pendingEventKeys.clear()
    removeGoogleAnalyticsCookies()
  }
}

export function trackPageView() {
  const measurementId = configuredMeasurementId || measurementIdFromPage()
  if (!measurementId || analyticsConsent() !== true) return

  const pageLocation = `${window.location.origin}${window.location.pathname}`
  if (pageLocation === lastPageViewLocation) return

  pendingPageView = {
    page_location: pageLocation,
    page_path: window.location.pathname,
    page_title: document.title
  }
  enableAnalyticsIfConsented(measurementId)
  flushPageView()
}

// Point d'extension volontairement unique pour les futurs lots ecommerce.
// Les événements restent bloqués tant que le consentement analytics n'est pas
// explicite.
export function trackAnalyticsEvent(name, parameters = {}, { dedupeKey } = {}) {
  const measurementId = configuredMeasurementId || measurementIdFromPage()
  if (!measurementId || analyticsConsent() !== true) return false
  if (dedupeKey && (sentEventKeys.has(dedupeKey) || pendingEventKeys.has(dedupeKey))) return false

  initializeConsentMode()
  const event = { name, parameters, dedupeKey }
  if (!googleTagReady) {
    pendingEvents.push(event)
    if (dedupeKey) pendingEventKeys.add(dedupeKey)
    enableAnalyticsIfConsented(measurementId)
    return true
  }

  return sendAnalyticsEvent(event)
}

function measurementIdFromPage() {
  return document.querySelector("meta[name='ga4-measurement-id']")?.content
}

function initializeConsentMode() {
  if (consentModeInitialized) return

  window.dataLayer = window.dataLayer || []
  window.gtag = window.gtag || function gtag() { window.dataLayer.push(arguments) }
  window.gtag("consent", "default", consentState(false))
  consentModeInitialized = true
}

function enableAnalyticsIfConsented(measurementId) {
  if (!measurementId || analyticsConsent() !== true) return

  configuredMeasurementId = measurementId
  if (googleTagReady || loading) return

  loading = true
  const script = document.createElement("script")
  script.async = true
  script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(measurementId)}`
  script.onload = () => {
    loading = false
    googleTagReady = true
    // La bibliothèque gtag attend cette initialisation avant sa configuration.
    // `send_page_view: false` conserve un seul envoi manuel, compatible Turbo.
    window.gtag("js", new Date())
    window.gtag("consent", "update", consentState(true))
    window.gtag("config", measurementId, { send_page_view: false })
    flushPageView()
    flushPendingEvents()
  }
  script.onerror = () => { loading = false }
  document.head.append(script)
}

function flushPageView() {
  if (!googleTagReady || !pendingPageView) return

  window.gtag("event", "page_view", pendingPageView)
  lastPageViewLocation = pendingPageView.page_location
  pendingPageView = undefined
}

function flushPendingEvents() {
  const events = pendingEvents
  pendingEvents = []
  events.forEach((event) => {
    if (event.dedupeKey) pendingEventKeys.delete(event.dedupeKey)
    sendAnalyticsEvent(event)
  })
}

function sendAnalyticsEvent({ name, parameters, dedupeKey }) {
  if (dedupeKey && sentEventKeys.has(dedupeKey)) return false

  try {
    window.gtag("event", name, parameters)
    if (dedupeKey) sentEventKeys.add(dedupeKey)
    return true
  } catch {
    return false
  }
}

function consentState(analytics) {
  return {
    ad_storage: "denied",
    ad_user_data: "denied",
    ad_personalization: "denied",
    analytics_storage: analytics ? "granted" : "denied"
  }
}

function removeGoogleAnalyticsCookies() {
  document.cookie.split(";").forEach((cookie) => {
    const name = cookie.trim().split("=")[0]
    if (name === "_ga" || name.startsWith("_ga_")) {
      document.cookie = `${name}=; Max-Age=0; Path=/; SameSite=Lax`
    }
  })
}

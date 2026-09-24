import "@hotwired/turbo-rails"
import "controllers"
import { initializeAnalytics, trackPageView } from "analytics"

document.addEventListener("turbo:load", () => {
  initializeAnalytics()
  trackPageView()
})

import { Controller } from "@hotwired/stimulus"
import { trackAnalyticsEvent } from "analytics"

// Le payload est produit côté Rails. En particulier, `q` est réduit à un
// booléen : aucune requête de recherche libre ne quitte le navigateur.
export default class extends Controller {
  static values = { search: Object }

  connect() {
    if (!this.hasSearchValue) return

    trackAnalyticsEvent("search", this.searchValue, {
      dedupeKey: `search:${window.location.pathname}:${JSON.stringify(this.searchValue)}`
    })
  }
}

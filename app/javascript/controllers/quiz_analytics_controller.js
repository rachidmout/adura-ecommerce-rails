import { Controller } from "@hotwired/stimulus"
import { trackAnalyticsEvent } from "analytics"

const QUIZ_NAME = "perfume_finder"
const BUDGET_RANGES = new Set(["under_30", "30_40", "40_50", "50_plus", "open"])

// Le questionnaire transmet uniquement des choix déjà rendus par Rails. Les
// gardes ci-dessous évitent aussi d'envoyer une valeur injectée dans le DOM.
export default class extends Controller {
  static values = { started: Object, completed: Object, familySlugs: Array }

  connect() {
    if (this.hasStartedValue) this.track("quiz_started", this.startedValue)
    if (this.hasCompletedValue) this.track("quiz_completed", this.completedValue)
  }

  familySelected(event) {
    const family = event.currentTarget.value
    if (!this.familySlugsValue.includes(family) || family === this.selectedFamily) return

    this.selectedFamily = family
    this.track("quiz_family_selected", { quiz_name: QUIZ_NAME, family })
  }

  budgetSelected(event) {
    const budgetRange = event.currentTarget.value
    if (!BUDGET_RANGES.has(budgetRange) || budgetRange === this.selectedBudgetRange) return

    this.selectedBudgetRange = budgetRange
    this.track("quiz_budget_selected", { quiz_name: QUIZ_NAME, budget_range: budgetRange })
  }

  track(name, payload) {
    trackAnalyticsEvent(name, payload, { dedupeKey: `${name}:${window.location.pathname}:${JSON.stringify(payload)}` })
  }
}

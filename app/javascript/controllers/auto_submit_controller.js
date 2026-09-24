import { Controller } from "@hotwired/stimulus"

export default class AutoSubmitController extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}

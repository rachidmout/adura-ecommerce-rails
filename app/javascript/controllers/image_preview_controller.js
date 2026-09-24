import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview"]

  connect() {
    this.objectUrls = []
  }

  disconnect() {
    this.revokeObjectUrls()
  }

  preview() {
    this.revokeObjectUrls()
    this.previewTarget.replaceChildren()

    Array.from(this.inputTarget.files).forEach((file) => {
      const url = URL.createObjectURL(file)
      this.objectUrls.push(url)

      const item = document.createElement("div")
      item.className = "admin-image-preview-item"

      const image = document.createElement("img")
      image.src = url
      image.alt = `Prévisualisation de ${file.name}`
      item.appendChild(image)
      this.previewTarget.appendChild(item)
    })

    this.previewTarget.hidden = this.objectUrls.length === 0
  }

  revokeObjectUrls() {
    this.objectUrls.forEach((url) => URL.revokeObjectURL(url))
    this.objectUrls = []
  }
}

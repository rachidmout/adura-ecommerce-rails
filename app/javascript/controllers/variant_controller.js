import { Controller } from "@hotwired/stimulus"

export default class VariantController extends Controller {
  static targets = ["choice", "price", "stock", "variantId", "submit", "galleryTrack", "gallerySlide", "gallery", "thumbs", "thumb", "stickyPrice", "stickyVolume", "stickyStatus", "galleryPosition"]

  select(event) {
    const choice = event.currentTarget
    this.choiceTargets.forEach((target) => {
      target.classList.remove("is-selected")
      target.setAttribute("aria-pressed", "false")
    })
    choice.classList.add("is-selected")
    choice.setAttribute("aria-pressed", "true")
    this.variantIdTarget.value = choice.dataset.variantId
    this.priceTarget.textContent = choice.dataset.price
    this.stockTarget.textContent = choice.dataset.stockLabel
    this.stickyPriceTarget.textContent = choice.dataset.price
    this.stickyVolumeTarget.textContent = choice.dataset.variantLabel
    this.stickyStatusTarget.textContent = choice.dataset.stockLabel
    const available = choice.dataset.available === "true"
    this.submitTargets.forEach((target) => {
      target.disabled = !available
      target.value = available ? choice.dataset.addLabel : choice.dataset.unavailableLabel
    })
    this.renderGallery(JSON.parse(choice.dataset.images || "[]"))
  }

  showImage(event) {
    const thumb = event.currentTarget
    this.showImageAt(this.thumbTargets.indexOf(thumb))
  }

  syncGallery() {
    if (!this.hasGalleryTrackTarget || this.gallerySlideTargets.length < 2) return

    const slideWidth = this.galleryTrackTarget.clientWidth
    if (!slideWidth) return

    this.setActiveImage(Math.round(this.galleryTrackTarget.scrollLeft / slideWidth))
  }

  renderGallery(urls) {
    if (!this.hasGalleryTrackTarget || urls.length === 0) return

    const alt = this.galleryTargets[0]?.alt || this.galleryTrackTarget.dataset.galleryAlt || ""
    this.galleryTrackTarget.replaceChildren()
    this.thumbsTarget.innerHTML = ""
    this.thumbsTarget.hidden = urls.length < 2

    urls.forEach((url, index) => {
      const slide = document.createElement("div")
      slide.className = "product-gallery-slide"
      slide.dataset.variantTarget = "gallerySlide"

      const image = document.createElement("img")
      image.className = "product-gallery-image"
      image.src = url
      image.alt = alt
      image.loading = index === 0 ? "eager" : "lazy"
      image.decoding = "async"
      image.dataset.variantTarget = "gallery"
      slide.appendChild(image)
      this.galleryTrackTarget.appendChild(slide)

      const button = document.createElement("button")
      button.type = "button"
      button.className = index === 0 ? "product-gallery-thumb is-active" : "product-gallery-thumb"
      button.dataset.variantTarget = "thumb"
      button.dataset.action = "variant#showImage"
      button.dataset.imageUrl = url
      button.setAttribute("aria-pressed", index === 0)
      button.setAttribute("aria-label", `${this.thumbsTarget.dataset.imageLabel} ${index + 1}`)

      const thumbnail = image.cloneNode()
      thumbnail.alt = ""
      thumbnail.loading = "lazy"
      button.appendChild(thumbnail)

      this.thumbsTarget.appendChild(button)
    })

    this.showImageAt(0, "auto")
  }

  showImageAt(index, behavior = "smooth") {
    const total = this.gallerySlideTargets.length
    if (!total || !this.hasGalleryTrackTarget) return

    const activeIndex = Math.max(0, Math.min(index, total - 1))
    this.galleryTrackTarget.scrollTo({ left: this.galleryTrackTarget.clientWidth * activeIndex, behavior })
    this.setActiveImage(activeIndex)
  }

  setActiveImage(activeIndex) {
    const total = this.gallerySlideTargets.length
    this.thumbTargets.forEach((target) => {
      const isActive = this.thumbTargets.indexOf(target) === activeIndex
      target.classList.toggle("is-active", isActive)
      target.setAttribute("aria-pressed", isActive)
    })
    if (this.hasGalleryPositionTarget) {
      this.galleryPositionTarget.hidden = total < 2
      this.galleryPositionTarget.textContent = `${activeIndex + 1} / ${total}`
    }
  }
}

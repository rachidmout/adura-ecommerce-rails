class ProductImage < ApplicationRecord
  belongs_to :product
  belongs_to :product_variant, optional: true
  has_one_attached :file

  validates :alt_text, presence: true, length: { maximum: 180 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :acceptable_file

  # Plusieurs anciennes images du catalogue ont été enregistrées avec des
  # libellés génériques du type "Photo Eclaire". On conserve la valeur en
  # base (et donc les saisies admin explicites), mais le rendu public reçoit
  # un texte alternatif descriptif et stable, construit uniquement avec des
  # données réelles du produit. Les ALT déjà descriptifs restent inchangés.
  def alt_text
    stored = super
    return stored if stored.blank? || (!generic_alt_text?(stored) && !legacy_generated_alt_text?(stored))

    generated_alt_text
  end

  private

  def generic_alt_text?(value)
    normalized = value.to_s.strip.downcase
    normalized == product.name.to_s.strip.downcase || normalized.match?(/\A(photo|image)(\s+de)?\b/)
  end

  # Les images importées avant l'internationalisation recevaient ce gabarit
  # français exact depuis les seeds. Ce ne sont pas des ALT édités à la main :
  # les reconnaître permet de les générer dans la locale courante, tout en
  # laissant toute autre saisie admin strictement inchangée.
  def legacy_generated_alt_text?(value)
    return false if product.blank? || product.brand.blank?

    volume = product_variant&.label || primary_variant_label
    return false if volume.blank?

    identity = "#{product.name} de #{product.brand.name} · #{volume}"
    value.to_s == identity || value.to_s == "#{identity} avec coffret"
  end

  def generated_alt_text
    brand_name = product.brand&.name
    volume = product_variant&.label || primary_variant_label
    identity = [ brand_name, product.name, volume ].compact_blank.join(" ")

    if primary?
      I18n.t("products.image_alt.primary", identity: identity)
    else
      I18n.t("products.image_alt.secondary", identity: identity, position: position.to_i + 1)
    end
  end

  def primary_variant_label
    variant = product.product_variants.select(&:active?).min_by { |item| item.position || 0 }
    variant&.label
  end

  def acceptable_file
    return unless file.attached?

    errors.add(:file, "doit être une image JPG, PNG ou WebP") unless file.content_type.in?(%w[image/jpeg image/png image/webp])
    errors.add(:file, "ne doit pas dépasser 8 Mo") if file.byte_size > 8.megabytes
  end
end

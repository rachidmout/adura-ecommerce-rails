class Product < ApplicationRecord
  belongs_to :brand
  has_one :perfume_profile, dependent: :destroy
  has_many :product_variants, -> { order(:position, :id) }, dependent: :restrict_with_error
  has_many :product_images, -> { order(:position, :id) }, dependent: :destroy
  has_many :product_olfactory_families, dependent: :destroy
  has_many :olfactory_families, through: :product_olfactory_families
  has_many :product_olfactory_notes, dependent: :destroy
  has_many :olfactory_notes, through: :product_olfactory_notes
  has_many :reviews, dependent: :destroy
  has_many :promo_code_products, dependent: :destroy
  has_many :promo_codes, through: :promo_code_products
  has_many :product_redirects, dependent: :destroy

  accepts_nested_attributes_for :perfume_profile, update_only: true
  accepts_nested_attributes_for :product_variants, allow_destroy: false

  enum :status, { draft: "draft", published: "published", archived: "archived" }, validate: true

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :slug, with: ->(slug) { slug.to_s.strip.downcase }

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :short_description, length: { maximum: 255 }, allow_blank: true
  validates :meta_title, length: { maximum: 70 }, allow_blank: true
  validates :meta_description, length: { maximum: 160 }, allow_blank: true
  validate :published_product_is_complete, if: :published?

  after_update :record_slug_redirect, if: :saved_change_to_slug?

  scope :visible, -> { published.where.not(published_at: nil) }
  scope :featured, -> { visible.where(featured: true).order(:featured_position, :name) }
  scope :search, lambda { |query|
    return all if query.blank?

    escaped = sanitize_sql_like(query.to_s.strip)
    joins(:brand).where("products.name ILIKE :query OR brands.name ILIKE :query", query: "%#{escaped}%")
  }
  scope :in_stock, -> { where(id: ProductVariant.active.where("stock_quantity - reserved_stock_quantity > 0").select(:product_id)) }
  scope :out_of_stock, -> { where.not(id: ProductVariant.active.where("stock_quantity - reserved_stock_quantity > 0").select(:product_id)) }

  def to_param
    slug
  end

  def primary_family
    product_olfactory_families.includes(:olfactory_family).find(&:primary?)&.olfactory_family
  end

  def primary_image
    product_images.find(&:primary?) || product_images.first
  end

  def active_variants
    product_variants.select(&:active?)
  end

  def minimum_price_cents
    active_variants.map(&:price_cents).min
  end

  def available?
    active_variants.any?(&:available?)
  end

  def publish!
    update!(status: :published, published_at: Time.current)
  end

  def archive!
    update!(status: :archived, archived_at: Time.current)
  end

  # Calculé à la volée plutôt que dénormalisé : le catalogue est trop petit
  # (quelques dizaines de produits) pour qu'un compteur mis en cache vaille
  # le risque de désynchronisation.
  def average_rating
    reviews.approved.average(:rating)
  end

  def reviews_count
    reviews.approved.count
  end

  # Pas de score arbitraire : seuls les deux champs saisissables à la main
  # comptent (les autres, comme le texte alternatif des images, sont déjà
  # obligatoires ailleurs et donc toujours renseignés).
  def seo_complete?
    meta_title.present? && meta_description.present?
  end

  private

  def record_slug_redirect
    old_slug = saved_change_to_slug.first
    return if old_slug.blank?

    product_redirects.find_or_create_by!(old_slug: old_slug)
  end

  def published_product_is_complete
    errors.add(:description, "doit être renseignée avant publication") if description.blank?
    errors.add(:perfume_profile, "doit être renseigné avant publication") if perfume_profile.blank?
    errors.add(:olfactory_families, "doivent contenir exactement une famille principale") unless product_olfactory_families.count(&:primary?) == 1
    errors.add(:product_variants, "doivent contenir au moins une variante active") unless product_variants.any? { |variant| variant.active? && variant.price_cents.positive? }
    errors.add(:product_images, "doivent contenir une image principale attachée") unless product_images.any? { |image| image.primary? && image.file.attached? }
    errors.add(:source_urls, "doivent contenir au moins une source") if source_urls.blank?
    errors.add(:verified_at, "doit être renseignée avant publication") if verified_at.blank?
  end
end

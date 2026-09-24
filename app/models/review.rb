class Review < ApplicationRecord
  belongs_to :product

  enum :status, { pending: "pending", approved: "approved", hidden: "hidden" }, validate: true

  normalizes :author_name, with: ->(name) { name.to_s.strip }
  normalizes :author_email, with: ->(email) { email.to_s.strip.downcase }

  validates :author_name, presence: true, length: { maximum: 120 }
  validates :author_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :comment, presence: true, length: { maximum: 2000 }
  validate :rating_in_range

  scope :approved, -> { where(status: "approved") }
  scope :recent, -> { order(created_at: :desc) }

  before_validation :compute_verified_purchase, on: :create

  private

  def rating_in_range
    errors.add(:rating, I18n.t("products.show.reviews_rating_invalid")) unless rating.to_i.between?(1, 5)
  end

  # "Achat vérifié" : une commande payée avec le même e-mail contenant un
  # article lié à ce produit. Si la variante a depuis été supprimée
  # (product_variant_id devient nul via dependent: :nullify), on ne peut
  # plus le vérifier — verified_purchase reste alors false plutôt que de
  # deviner, ce qui est un compromis assumé, pas un bug.
  def compute_verified_purchase
    return if product_id.blank? || author_email.blank?

    self.verified_purchase = Order.completed
      .where(email: author_email)
      .joins(order_items: :product_variant)
      .where(product_variants: { product_id: product_id })
      .exists?
  end
end

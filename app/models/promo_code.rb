class PromoCode < ApplicationRecord
  has_many :promo_code_products, dependent: :destroy
  has_many :products, through: :promo_code_products
  has_many :promo_code_olfactory_families, dependent: :destroy
  has_many :olfactory_families, through: :promo_code_olfactory_families
  has_many :orders, dependent: :restrict_with_error

  enum :discount_type, { percentage: "percentage", fixed_amount: "fixed_amount" }, validate: true

  normalizes :code, with: ->(code) { code.to_s.strip.upcase }

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :discount_value, numericality: { only_integer: true, greater_than: 0 }
  validates :discount_value, numericality: { less_than_or_equal_to: 100 }, if: :percentage?
  validates :max_uses, :max_uses_per_customer, :min_order_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :ends_at_after_starts_at

  scope :active_now, lambda {
    now = Time.current
    where(active: true).where("(starts_at IS NULL OR starts_at <= :now) AND (ends_at IS NULL OR ends_at >= :now)", now: now)
  }

  # Un code sans produit/famille associé s'applique à tout le catalogue —
  # pas besoin d'un champ booléen "scoped" séparé à garder synchronisé.
  def scoped?
    promo_code_products.exists? || promo_code_olfactory_families.exists?
  end

  def applies_to?(product)
    applies_to_product_id?(product.id)
  end

  def applies_to_product_id?(product_id)
    return true unless scoped?

    products.exists?(id: product_id) || olfactory_families.joins(:products).where(products: { id: product_id }).exists?
  end

  # Calcul pur : jamais négatif, jamais au-delà du sous-total. Ne fait
  # confiance à aucune donnée venant du client — subtotal_cents doit déjà
  # être calculé côté Rails à partir des prix en base.
  def discount_for(subtotal_cents)
    raw = percentage? ? (subtotal_cents * discount_value / 100.0).round : discount_value
    raw.clamp(0, subtotal_cents)
  end

  def uses_count
    orders.completed.count
  end

  def uses_count_for(email)
    orders.completed.where(email: email.to_s.strip.downcase).count
  end

  def revenue_generated_cents
    orders.completed.sum(:total_cents)
  end

  def discount_given_cents
    orders.completed.sum(:discount_cents)
  end

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "doit être postérieure à la date de début") if ends_at < starts_at
  end
end

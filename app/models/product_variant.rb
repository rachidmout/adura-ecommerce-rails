class ProductVariant < ApplicationRecord
  LOW_STOCK_THRESHOLD = 3

  belongs_to :product
  has_many :order_items, dependent: :nullify
  has_many :product_images, -> { order(:position, :id) }, dependent: :nullify
  has_many :stock_reservation_items, dependent: :restrict_with_error

  normalizes :sku, with: ->(sku) { sku.to_s.strip.upcase }
  normalizes :gtin, with: ->(gtin) { gtin.to_s.gsub(/\D/, "").presence }

  validates :sku, presence: true, uniqueness: true
  validates :gtin, uniqueness: true, allow_nil: true
  validates :volume_ml, numericality: { only_integer: true, greater_than: 0 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :shipping_weight_grams, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :stock_quantity, :reserved_stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, inclusion: { in: %w[EUR] }
  validate :active_variant_has_positive_price
  validate :price_euros_input_is_valid
  validate :reserved_stock_does_not_exceed_physical_stock

  scope :active, -> { where(active: true) }
  scope :low_stock, -> { where("stock_quantity - reserved_stock_quantity BETWEEN 0 AND ?", LOW_STOCK_THRESHOLD) }

  def available?
    active? && available_stock_quantity.positive? && product.published?
  end

  def available_stock_quantity
    stock_quantity - reserved_stock_quantity
  end

  def label
    "#{volume_ml} ml"
  end

  def historical?
    order_items.exists? || stock_reservation_items.exists?
  end

  # Attribut virtuel pour l'admin : le formulaire saisit/affiche un prix en
  # euros ("18.00"), jamais price_cents directement (source d'erreurs comme
  # taper "18" au lieu de "1800"). BigDecimal plutôt qu'un calcul en Float
  # pour la conversion : 19.90 * 100 vaut 1989.9999999999998 en Float, alors
  # que (BigDecimal("19.90") * 100) vaut exactement 1990.
  def price_euros
    @price_euros_input || (price_cents && price_cents / 100.0)
  end

  def price_euros=(value)
    @price_euros_input = value
    cents = self.class.cents_from_euros(value)
    self.price_cents = cents if cents && !cents.negative?
  end

  def self.cents_from_euros(value)
    return nil if value.blank?

    (BigDecimal(value.to_s.tr(",", ".")) * 100).round
  rescue ArgumentError, TypeError
    nil
  end

  def self.next_sku(product_slug:, volume_ml:)
    base_sku = "ADURA-#{product_slug.to_s.upcase}-#{volume_ml}"
    suffix = 1
    candidate = base_sku

    while exists?(sku: candidate)
      suffix += 1
      candidate = "#{base_sku}-#{suffix}"
    end

    candidate
  end

  # Les photos dédiées à un format restent prioritaires. Quand aucune photo
  # n'est rattachée à la variante, on affiche toutes les photos génériques du
  # produit (product_variant_id = NULL), dans leur ordre admin. Cela évite que
  # les fiches à une seule variante n'affichent que l'image principale alors
  # que plusieurs photos génériques ont bien été ajoutées.
  def gallery_images
    variant_images = product_images.to_a
    return variant_images if variant_images.any?

    generic_images = product.product_images.where(product_variant_id: nil).order(:position, :id).to_a
    generic_images.presence || Array(product.primary_image)
  end

  private

  def active_variant_has_positive_price
    errors.add(:price_cents, "doit être supérieur à zéro pour une variante active") if active? && !price_cents.positive?
  end

  def reserved_stock_does_not_exceed_physical_stock
    return if reserved_stock_quantity.to_i <= stock_quantity.to_i

    errors.add(:reserved_stock_quantity, "ne peut pas dépasser le stock physique")
  end

  # Ne se déclenche que si le formulaire admin a été utilisé (price_euros=
  # appelé) : price_cents affecté directement (seeds, console) n'est jamais
  # concerné par cette validation, qui reste dédiée à la saisie en euros.
  def price_euros_input_is_valid
    return if @price_euros_input.nil?

    cents = self.class.cents_from_euros(@price_euros_input)
    errors.add(:price_euros, "doit être un nombre positif, par exemple 18.00") if cents.nil? || cents.negative?
  end
end

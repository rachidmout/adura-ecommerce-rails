class Cart
  class Error < StandardError; end
  class UnavailableVariant < Error; end
  class InvalidQuantity < Error; end

  Line = Data.define(:variant, :quantity) do
    def unit_price_cents = variant.price_cents
    def line_total_cents = unit_price_cents * quantity
    def product = variant.product
  end

  def initialize(session)
    @session = session
  end

  def lines
    variant_ids = raw_items.keys.map(&:to_i)
    variants = ProductVariant.includes(product: [ :brand, :product_images ]).where(id: variant_ids).index_by(&:id)

    raw_items.filter_map do |variant_id, quantity|
      variant = variants[variant_id.to_i]
      next unless variant

      Line.new(variant: variant, quantity: quantity.to_i)
    end
  end

  def add(variant_id, quantity = 1)
    variant = ProductVariant.includes(:product).find(variant_id)
    quantity = quantity.to_i
    raise InvalidQuantity, I18n.t("carts.errors.invalid_quantity") unless quantity.positive?
    raise UnavailableVariant, I18n.t("carts.errors.unavailable_variant") unless variant.available?

    next_quantity = [ raw_items.fetch(variant.id.to_s, 0).to_i + quantity, variant.stock_quantity ].min
    raw_items[variant.id.to_s] = next_quantity
  end

  def update(variant_id, quantity)
    variant = ProductVariant.find(variant_id)
    quantity = quantity.to_i
    return remove(variant_id) unless quantity.positive?
    raise UnavailableVariant, I18n.t("carts.errors.stock_changed") unless variant.available?

    raw_items[variant.id.to_s] = [ quantity, variant.stock_quantity ].min
  end

  def remove(variant_id)
    raw_items.delete(variant_id.to_s)
  end

  def clear
    @session.delete(:cart)
  end

  def empty?
    raw_items.empty?
  end

  def count
    raw_items.values.sum(&:to_i)
  end

  def subtotal_cents
    lines.sum(&:line_total_cents)
  end

  private

  def raw_items
    @session[:cart] ||= {}
  end
end

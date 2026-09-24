class ProductOlfactoryNote < ApplicationRecord
  belongs_to :product
  belongs_to :olfactory_note

  enum :layer, { top: "top", heart: "heart", base: "base" }, validate: true

  validates :olfactory_note_id, uniqueness: { scope: %i[product_id layer] }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :display_order, -> { order(:layer, :position, :id) }
end

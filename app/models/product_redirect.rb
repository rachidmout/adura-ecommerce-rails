class ProductRedirect < ApplicationRecord
  belongs_to :product

  normalizes :old_slug, with: ->(slug) { slug.to_s.strip.downcase }

  validates :old_slug, presence: true, uniqueness: true
end

class ProductOlfactoryFamily < ApplicationRecord
  belongs_to :product
  belongs_to :olfactory_family

  enum :role, { primary: "primary", secondary: "secondary" }, validate: true

  validates :olfactory_family_id, uniqueness: { scope: :product_id }
end

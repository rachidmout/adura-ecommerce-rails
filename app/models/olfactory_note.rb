class OlfactoryNote < ApplicationRecord
  has_many :product_olfactory_notes, dependent: :restrict_with_error
  has_many :products, through: :product_olfactory_notes

  validates :name, :slug, presence: true
  validates :name, uniqueness: { case_sensitive: false }
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  scope :active, -> { where(active: true).order(:name) }
end

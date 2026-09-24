class OlfactoryFamily < ApplicationRecord
  has_many :product_olfactory_families, dependent: :restrict_with_error
  has_many :products, through: :product_olfactory_families
  has_many :promo_code_olfactory_families, dependent: :destroy
  has_many :promo_codes, through: :promo_code_olfactory_families

  validates :name, :slug, presence: true
  validates :name, uniqueness: { case_sensitive: false }
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :meta_title, length: { maximum: 70 }, allow_blank: true
  validates :meta_description, length: { maximum: 160 }, allow_blank: true

  scope :active, -> { where(active: true).order(:name) }
end

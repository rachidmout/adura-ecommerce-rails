class Brand < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, :slug, presence: true
  validates :name, uniqueness: { case_sensitive: false }
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  scope :active, -> { where(active: true) }
end

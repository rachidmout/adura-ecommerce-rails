class AdminUser < ApplicationRecord
  has_secure_password

  has_many :order_status_events, dependent: :nullify
  has_many :updated_shop_settings,
    class_name: "ShopSetting",
    foreign_key: :updated_by_admin_user_id,
    inverse_of: :updated_by_admin_user,
    dependent: :nullify

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }

  scope :active, -> { where(active: true) }
end

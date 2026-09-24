class PromoCodeOlfactoryFamily < ApplicationRecord
  belongs_to :promo_code
  belongs_to :olfactory_family

  validates :olfactory_family_id, uniqueness: { scope: :promo_code_id }
end

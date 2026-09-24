class Order < ApplicationRecord
  TRACKING_URL_TEMPLATES = {
    "Colissimo / La Poste" => "https://www.laposte.fr/outils/track-a-parcel?code=%{tracking_number}",
    "Chronopost" => "https://www.chronopost.fr/tracking-no-cms/suivi-page?langue=fr&listeNumerosLT=%{tracking_number}",
    "DHL" => "https://www.dhl.com/fr-fr/home/tracking.html?tracking-id=%{tracking_number}",
    "UPS" => "https://www.ups.com/track?loc=fr_FR&tracknum=%{tracking_number}",
    "FedEx" => "https://www.fedex.com/fedextrack/?trknbr=%{tracking_number}"
  }.freeze
  PUBLIC_TRACKING_PAGES = {
    "Mondial Relay" => "https://www.mondialrelay.fr/suivi-de-colis/"
  }.freeze

  has_secure_token :public_token

  has_many :order_items, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :order_status_events, dependent: :restrict_with_error
  has_one :relay_point, class_name: "OrderRelayPoint", dependent: :restrict_with_error
  has_one :shipment, dependent: :restrict_with_error
  belongs_to :promo_code, optional: true

  enum :status, {
    pending: "pending",
    paid: "paid",
    preparing: "preparing",
    shipped: "shipped",
    cancelled: "cancelled",
    payment_review: "payment_review"
  }, validate: true

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :country_code, with: ->(country_code) { country_code.to_s.strip.upcase }

  # Commandes réellement payées et jamais annulées depuis, quel que soit leur
  # statut actuel. Le scope `paid` généré par l'enum ci-dessus ne matche que
  # status == "paid" et exclut donc à tort les commandes déjà expédiées :
  # pour tout ce qui touche au chiffre d'affaires (dashboard admin), c'est
  # `completed` qu'il faut utiliser, pas l'enum. Le "where.not(status:
  # cancelled)" n'a aujourd'hui aucun effet pratique (rien dans le code ne
  # permet encore d'annuler une commande déjà payée), mais protège le calcul
  # du CA dès qu'une telle fonctionnalité existera.
  scope :completed, -> { where.not(paid_at: nil).where.not(status: :cancelled) }
  scope :awaiting_shipment, -> { where(status: %i[paid preparing]) }

  validates :public_token, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, :phone, :address_line1, :postal_code, :city, presence: true
  validates :country_code, presence: true
  validates :currency, inclusion: { in: %w[EUR] }
  validates :subtotal_cents, :shipping_cents, :total_cents, :discount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :total_matches_components
  validate :country_is_available_for_checkout
  validate :postal_code_matches_country
  validate :contains_at_least_one_item, on: :update

  def customer_name
    "#{first_name} #{last_name}".strip
  end

  def shipping_country_name
    I18n.t("countries.#{country_code}", default: ShippingZoneCountry::COUNTRIES.fetch(country_code, country_code))
  end

  # Le dernier essai de paiement, sans requête supplémentaire si `payments`
  # est déjà eager-loadée (utilisé par la liste des commandes admin).
  def latest_payment
    payments.max_by(&:created_at)
  end

  def payable?
    pending? && order_items.any?
  end

  def mark_shipped!(admin_user:, shipping_carrier:, tracking_number:)
    transaction do
      lock!
      carrier = shipping_carrier.to_s.strip
      tracking = tracking_number.to_s.strip
      validate_shipping_transition!(shipping_carrier: carrier, tracking_number: tracking)

      previous = status
      update!(
        status: :shipped,
        shipped_at: Time.current,
        shipping_carrier: carrier,
        tracking_number: tracking
      )
      order_status_events.create!(from_status: previous, to_status: status, source: "admin", admin_user: admin_user)
      OrderMailer.with(order: self).shipped.deliver_later
    end
  end

  def mark_preparing!(admin_user:)
    transaction do
      lock!
      raise ActiveRecord::RecordInvalid, self unless paid?

      previous = status
      update!(status: :preparing, preparing_at: Time.current)
      order_status_events.create!(from_status: previous, to_status: status, source: "admin", admin_user: admin_user)
    end
  end

  def tracking_url
    return if shipping_carrier.blank? || tracking_number.blank?
    return PUBLIC_TRACKING_PAGES[shipping_carrier] if PUBLIC_TRACKING_PAGES.key?(shipping_carrier)

    template = TRACKING_URL_TEMPLATES[shipping_carrier]
    template % { tracking_number: URI.encode_www_form_component(tracking_number) } if template
  end

  private

  def validate_shipping_transition!(shipping_carrier:, tracking_number:)
    errors.clear
    errors.add(:status, "doit être payée ou en préparation pour être expédiée") unless paid? || preparing?
    errors.add(:shipping_carrier, "doit être renseigné") if shipping_carrier.blank?
    errors.add(:tracking_number, "doit être renseigné") if tracking_number.blank?
    raise ActiveRecord::RecordInvalid, self if errors.any?
  end

  def total_matches_components
    errors.add(:total_cents, "ne correspond pas au sous-total, à la livraison et à la réduction") unless total_cents == subtotal_cents + shipping_cents - discount_cents
  end

  def country_is_available_for_checkout
    return if country_code.blank? || Checkout::SupportedCountries.allowed?(country_code)

    errors.add(:country_code, I18n.t("checkouts.errors.country_unsupported"))
  end

  def postal_code_matches_country
    return if postal_code.blank? || country_code != "FR" || postal_code.match?(/\A\d{5}\z/)

    errors.add(:postal_code, I18n.t("checkouts.errors.postal_code_invalid"))
  end

  def contains_at_least_one_item
    errors.add(:order_items, "doit contenir au moins un article") if order_items.empty?
  end
end

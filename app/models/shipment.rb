class Shipment < ApplicationRecord
  STATUSES = %w[pending created label_ready failed].freeze

  belongs_to :order
  has_one_attached :label

  enum :status, STATUSES.index_with(&:itself), validate: true

  normalizes :carrier, :service, :carrier_shipment_id, :tracking_number, :tracking_url, :label_url, :error_message,
             with: ->(value) { value.to_s.strip.presence }

  validates :carrier, :service, presence: true
  validates :order_id, uniqueness: true
  validates :carrier_shipment_id, :tracking_number, presence: true, if: :created_or_label_ready?
  validates :carrier_shipment_id, uniqueness: { scope: :carrier }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validate :acceptable_label

  def ready?
    created? || label_ready?
  end

  def label_available?
    label.attached? || label_url.present?
  end

  private

  def created_or_label_ready?
    created? || label_ready?
  end

  def acceptable_label
    return unless label.attached?

    errors.add(:label, "doit être un PDF") unless label.content_type == "application/pdf"
    errors.add(:label, "ne doit pas dépasser 10 Mo") if label.byte_size > 10.megabytes
  end
end

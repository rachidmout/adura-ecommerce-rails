class PaymentEvent < ApplicationRecord
  belongs_to :payment, optional: true

  enum :status, { received: "received", processed: "processed", ignored: "ignored", failed: "failed" }, validate: true

  # Pas de validation d'unicité applicative ici : PaymentEvent.create_or_find_by!
  # (dans Payments::ProcessStripeEvent) doit pouvoir rattraper une tentative de
  # doublon via ActiveRecord::RecordNotUnique, ce qui suppose que la seule
  # barrière d'unicité soit l'index unique en base (voir db/schema.rb,
  # table "payment_events", colonne "stripe_event_id"). Une validation Rails
  # ici lèverait RecordInvalid *avant* d'atteindre la base, ce que
  # create_or_find_by! ne sait pas rattraper.
  validates :stripe_event_id, :event_type, presence: true
end

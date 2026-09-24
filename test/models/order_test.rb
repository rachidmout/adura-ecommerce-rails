require "test_helper"

class OrderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper
  test "rejects an inconsistent total" do
    order = Order.new(
      email: "client@example.com", first_name: "A", last_name: "Client", phone: "0600000000",
      address_line1: "1 rue du Test", postal_code: "75001", city: "Paris", country_code: "FR",
      subtotal_cents: 2_000, shipping_cents: 490, total_cents: 2_000,
      shipping_rate_snapshot_cents: 490, terms_accepted_at: Time.current
    )
    assert_not order.valid?
    assert_includes order.errors[:total_cents], "ne correspond pas au sous-total, à la livraison et à la réduction"
  end

  test "order status labels are translated without changing enum values" do
    expected_labels = {
      pending: "En attente",
      paid: "Payée",
      preparing: "En préparation",
      shipped: "Expédiée",
      cancelled: "Annulée",
      payment_review: "Paiement à vérifier"
    }

    expected_labels.each do |status, label|
      assert_equal label, ApplicationController.helpers.order_status_label(status)
      assert_equal status.to_s, Order.statuses.fetch(status.to_s)
    end
    assert_equal "Future status", ApplicationController.helpers.order_status_label("future_status")
  end

  test "shipping country name is readable for configured countries and safe for legacy values" do
    order = Order.new(country_code: "MA")

    assert_equal "Maroc", order.shipping_country_name
    order.country_code = "XX"
    assert_equal "XX", order.shipping_country_name
  end

  test "completed only counts orders that were actually paid, including prepared and shipped ones" do
    variant = create_publishable_product.product_variants.first

    paid = create_paid_order(variant: variant, status: :paid)
    preparing = create_paid_order(variant: variant, status: :paid)
    preparing.mark_preparing!(admin_user: create_admin_user(email: "preparing-completed@adura.local"))
    shipped = create_paid_order(variant: variant, status: :shipped)
    create_paid_order(variant: variant, status: :pending)
    cancelled = create_paid_order(variant: variant, status: :paid)
    cancelled.update!(status: :cancelled)

    assert_equal [ paid, preparing, shipped ].sort_by(&:id), Order.completed.order(:id).to_a
    assert_equal paid.total_cents + preparing.total_cents + shipped.total_cents, Order.completed.sum(:total_cents)
  end

  test "mark_preparing transitions a paid order with an audited timestamp" do
    admin = create_admin_user
    order = create_paid_order(status: :paid)

    order.mark_preparing!(admin_user: admin)

    order.reload
    event = order.order_status_events.last
    assert order.preparing?
    assert_not_nil order.preparing_at
    assert_equal "paid", event.from_status
    assert_equal "preparing", event.to_status
    assert_equal "admin", event.source
    assert_equal admin, event.admin_user
  end

  test "mark_preparing refuses every non-paid status and a second transition" do
    admin = create_admin_user
    pending = create_paid_order(status: :pending)
    payment_review = create_paid_order(status: :pending)
    payment_review.update!(status: :payment_review)
    cancelled = create_paid_order(status: :pending)
    cancelled.update!(status: :cancelled)
    shipped = create_paid_order(status: :shipped)
    preparing = create_paid_order(status: :paid)
    preparing.mark_preparing!(admin_user: admin)

    [ pending, payment_review, cancelled, shipped, preparing ].each do |order|
      assert_raises(ActiveRecord::RecordInvalid) { order.mark_preparing!(admin_user: admin) }
    end
  end

  test "mark_preparing rolls back when the status event cannot be created" do
    order = create_paid_order(status: :paid)
    order.define_singleton_method(:order_status_events) { raise "status event failure" }

    assert_raises(RuntimeError, "status event failure") { order.mark_preparing!(admin_user: create_admin_user) }

    order.reload
    assert order.paid?
    assert_nil order.preparing_at
    assert_equal 0, OrderStatusEvent.where(order: order).count
  end

  test "awaiting_shipment includes paid and preparing orders but not shipped orders" do
    admin = create_admin_user
    paid = create_paid_order(status: :paid)
    preparing = create_paid_order(status: :paid)
    preparing.mark_preparing!(admin_user: admin)
    shipped = create_paid_order(status: :shipped)

    assert_equal [ paid, preparing ].sort_by(&:id), Order.awaiting_shipment.order(:id).to_a
    assert_not_includes Order.awaiting_shipment, shipped
  end

  test "mark_shipped transitions paid and preparing orders with audited shipping details" do
    admin = create_admin_user
    paid = create_paid_order(status: :paid)
    preparing = create_paid_order(status: :paid)
    preparing.mark_preparing!(admin_user: admin)

    paid.mark_shipped!(admin_user: admin, shipping_carrier: "Colissimo / La Poste", tracking_number: "6A12345678901")
    preparing.mark_shipped!(admin_user: admin, shipping_carrier: "DHL", tracking_number: "JD0146000000")

    [ [ paid, "paid", "Colissimo / La Poste", "6A12345678901" ], [ preparing, "preparing", "DHL", "JD0146000000" ] ].each do |order, from_status, carrier, tracking|
      order.reload
      event = order.order_status_events.last
      assert order.shipped?
      assert_not_nil order.shipped_at
      assert_equal carrier, order.shipping_carrier
      assert_equal tracking, order.tracking_number
      assert_equal from_status, event.from_status
      assert_equal "shipped", event.to_status
      assert_equal "admin", event.source
      assert_equal admin, event.admin_user
    end
  end

  test "mark_shipped refuses invalid statuses, a duplicate transition, and missing shipping details" do
    admin = create_admin_user
    pending = create_paid_order(status: :pending)
    payment_review = create_paid_order(status: :pending)
    payment_review.update!(status: :payment_review)
    cancelled = create_paid_order(status: :pending)
    cancelled.update!(status: :cancelled)
    shipped = create_paid_order(status: :shipped)

    [ pending, payment_review, cancelled, shipped ].each do |order|
      assert_raises(ActiveRecord::RecordInvalid) { order.mark_shipped!(admin_user: admin, shipping_carrier: "DHL", tracking_number: "TRACK-1") }
    end

    paid = create_paid_order(status: :paid)
    assert_raises(ActiveRecord::RecordInvalid) { paid.mark_shipped!(admin_user: admin, shipping_carrier: " ", tracking_number: "TRACK-2") }
    assert_raises(ActiveRecord::RecordInvalid) { paid.mark_shipped!(admin_user: admin, shipping_carrier: "DHL", tracking_number: " ") }
    assert paid.reload.paid?
    assert_nil paid.shipping_carrier
    assert_nil paid.tracking_number
  end

  test "mark_shipped rolls back shipping details when the status event cannot be created" do
    order = create_paid_order(status: :paid)
    order.define_singleton_method(:order_status_events) { raise "status event failure" }

    assert_no_enqueued_emails do
      assert_raises(RuntimeError, "status event failure") do
        order.mark_shipped!(admin_user: create_admin_user, shipping_carrier: "UPS", tracking_number: "1Z999AA10123456784")
      end
    end

    order.reload
    assert order.paid?
    assert_nil order.shipped_at
    assert_nil order.shipping_carrier
    assert_nil order.tracking_number
    assert_equal 0, OrderStatusEvent.where(order: order).count
  end

  test "mark_shipped enqueues one shipped email only after a successful transition" do
    order = create_paid_order(status: :paid)
    admin = create_admin_user

    assert_enqueued_email_with OrderMailer, :shipped, params: { order: order } do
      order.mark_shipped!(admin_user: admin, shipping_carrier: "UPS", tracking_number: "1Z999AA10123456784")
    end

    assert_raises(ActiveRecord::RecordInvalid) do
      order.mark_shipped!(admin_user: admin, shipping_carrier: "UPS", tracking_number: "1Z999AA10123456784")
    end
    assert_equal 1, enqueued_jobs.count { |job| job["arguments"].include?("shipped") }
  end

  test "tracking_url uses official carrier pages and encodes the tracking number" do
    order = create_paid_order
    order.tracking_number = "AB 12&34"

    expected_urls = {
      "Colissimo / La Poste" => "https://www.laposte.fr/outils/track-a-parcel?code=AB+12%2634",
      "Chronopost" => "https://www.chronopost.fr/tracking-no-cms/suivi-page?langue=fr&listeNumerosLT=AB+12%2634",
      "DHL" => "https://www.dhl.com/fr-fr/home/tracking.html?tracking-id=AB+12%2634",
      "UPS" => "https://www.ups.com/track?loc=fr_FR&tracknum=AB+12%2634",
      "FedEx" => "https://www.fedex.com/fedextrack/?trknbr=AB+12%2634"
    }

    expected_urls.each do |carrier, url|
      order.shipping_carrier = carrier
      assert_equal url, order.tracking_url
    end

    order.shipping_carrier = "Mondial Relay"
    assert_equal "https://www.mondialrelay.fr/suivi-de-colis/", order.tracking_url
    order.shipping_carrier = "Autre"
    assert_nil order.tracking_url
  end

  test "latest_payment returns the most recently created payment" do
    order = create_paid_order
    older_payment = order.payments.create!(amount_cents: order.total_cents, currency: "EUR", status: :failed, created_at: 2.days.ago)
    newer_payment = order.payments.create!(amount_cents: order.total_cents, currency: "EUR", status: :succeeded, created_at: 1.hour.ago)

    assert_equal newer_payment, order.reload.latest_payment
    assert_not_equal older_payment, order.latest_payment
  end
end

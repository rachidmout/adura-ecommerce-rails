require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  test "renders a confirmation email for the order" do
    order = create_paid_order

    mail = OrderMailer.with(order: order).confirmation

    assert_equal [ order.email ], mail.to
    assert_equal "Confirmation de votre commande ADURA", mail.subject
    assert_match order.first_name, mail.html_part.body.decoded
    assert_match order.public_token.first(8).upcase, mail.html_part.body.decoded
    assert_match order.first_name, mail.text_part.body.decoded
    assert_match order.public_token.first(8).upcase, mail.text_part.body.decoded
  end

  test "deliver_later serializes the order through GlobalID" do
    order = create_paid_order

    assert_enqueued_email_with OrderMailer, :confirmation, params: { order: order } do
      OrderMailer.with(order: order).confirmation.deliver_later
    end
  end

  test "renders the selected relay point in the confirmation email" do
    order = create_paid_order
    order.create_relay_point!(carrier: "Mondial Relay", relay_id: "MR-75001-001", relay_name: "Relais Paris",
                              relay_address_line1: "1 rue de Test", relay_postal_code: "75001", relay_city: "Paris", relay_country: "FR")

    mail = OrderMailer.with(order: order).confirmation

    assert_match "Livraison en point relais", mail.html_part.body.decoded
    assert_match "Relais Paris", mail.html_part.body.decoded
    assert_match "MR-75001-001", mail.text_part.body.decoded
  end

  test "renders a shipped email with the official tracking link" do
    order = create_paid_order
    order.update!(shipping_carrier: "Chronopost", tracking_number: "XY 12&34")
    order.country_code = "MA"

    mail = OrderMailer.with(order: order).shipped

    assert_equal [ order.email ], mail.to
    assert_equal "Votre commande ADURA est expédiée", mail.subject
    assert_match order.shipping_carrier, mail.html_part.body.decoded
    assert_match ERB::Util.html_escape(order.tracking_number), mail.html_part.body.decoded
    assert_match "Suivre mon colis", mail.html_part.body.decoded
    assert_match ERB::Util.html_escape(order.tracking_url), mail.html_part.body.decoded
    assert_match order.shipping_carrier, mail.text_part.body.decoded
    assert_match order.tracking_number, mail.text_part.body.decoded
    assert_match order.tracking_url, mail.text_part.body.decoded
    assert_match "Maroc", mail.html_part.body.decoded
    assert_match "Maroc", mail.text_part.body.decoded
  end

  test "renders the tracking and relay destination in a shipped email" do
    order = create_paid_order
    order.update!(shipping_carrier: "Mondial Relay", tracking_number: "12345678")
    order.create_relay_point!(carrier: "Mondial Relay", relay_id: "MR-75001-001", relay_name: "Relais Paris",
                              relay_address_line1: "1 rue de Test", relay_postal_code: "75001", relay_city: "Paris", relay_country: "FR")

    mail = OrderMailer.with(order: order).shipped

    assert_match "12345678", mail.html_part.body.decoded
    assert_match "Relais Paris", mail.html_part.body.decoded
    assert_match order.tracking_url, mail.html_part.body.decoded
    assert_match "MR-75001-001", mail.text_part.body.decoded
  end

  test "renders a shipped email without a tracking link when none is available" do
    order = create_paid_order
    order.update!(shipping_carrier: "Autre", tracking_number: "LOCAL-42")

    mail = OrderMailer.with(order: order).shipped

    assert_match "LOCAL-42", mail.html_part.body.decoded
    assert_no_match "Suivre mon colis", mail.html_part.body.decoded
    assert_no_match "Suivre mon colis", mail.text_part.body.decoded
  end

  test "shipped deliver_later serializes the order through GlobalID" do
    order = create_paid_order

    assert_enqueued_email_with OrderMailer, :shipped, params: { order: order } do
      OrderMailer.with(order: order).shipped.deliver_later
    end
  end

  test "refuses to generate an email without a valid order" do
    error = assert_raises(ArgumentError) do
      OrderMailer.with(order: nil).confirmation.message
    end

    assert_equal "Une commande valide est requise.", error.message
  end
end

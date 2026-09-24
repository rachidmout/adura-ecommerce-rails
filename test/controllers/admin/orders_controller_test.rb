require "test_helper"

module Admin
  class OrdersControllerTest < ActionDispatch::IntegrationTest
    test "requires an authenticated admin" do
      get admin_orders_path
      assert_redirected_to admin_login_path
    end

    test "index filters by status" do
      sign_in_as(create_admin_user)
      paid = create_paid_order(status: :paid)
      pending = create_paid_order(status: :pending)

      get admin_orders_path, params: { status: "paid" }

      assert_select "td", text: paid.public_token.first(8).upcase
      assert_select "td", text: pending.public_token.first(8).upcase, count: 0
    end

    test "show displays payment information without exposing Stripe secrets" do
      sign_in_as(create_admin_user)
      order = create_paid_order
      order.update_column(:country_code, "MA")
      order.payments.create!(amount_cents: order.total_cents, currency: "EUR", status: :succeeded, checkout_session_id: "cs_test_demo_1", payment_intent_id: "pi_test_demo_1")

      get admin_order_path(order)

      assert_response :success
      assert_match "cs_test_demo_1", response.body
      assert_match "Maroc", response.body
      assert_no_match(/sk_(test|live)_/, response.body)
      assert_no_match(/whsec_/, response.body)
    end

    test "show displays a relay point separately from the customer address" do
      sign_in_as(create_admin_user)
      order = create_paid_order
      order.create_relay_point!(carrier: "Mondial Relay", relay_id: "MR-75001-001", relay_name: "Relais Paris",
                                relay_address_line1: "1 rue de Test", relay_postal_code: "75001", relay_city: "Paris", relay_country: "FR",
                                relay_opening_hours: "Lun–Sam : 09:00–19:00")

      get admin_order_path(order)

      assert_response :success
      assert_select "h2", text: "Point relais choisi"
      assert_select "p", text: /Relais Paris/
      assert_select "code", text: "MR-75001-001"
    end

    test "ship transitions a paid order with shipping details" do
      admin = create_admin_user
      sign_in_as(admin)
      order = create_paid_order(status: :paid)

      patch ship_admin_order_path(order), params: { shipment: { carrier_choice: "Colissimo / La Poste", tracking_number: "6A12345678901" } }

      assert_redirected_to admin_order_path(order)
      order.reload
      event = order.order_status_events.last
      assert order.shipped?
      assert_not_nil order.shipped_at
      assert_equal "Colissimo / La Poste", order.shipping_carrier
      assert_equal "6A12345678901", order.tracking_number
      assert_equal "paid", event.from_status
      assert_equal "shipped", event.to_status
      assert_equal admin, event.admin_user

      get admin_order_path(order)
      assert_select ".status-pill.shipped", text: "Expédiée"
      assert_select "td", text: /Payée → Expédiée/
    end

    test "creates a shipment from a paid order and exposes its tracking and label" do
      sign_in_as(create_admin_user)
      order = create_paid_order(status: :paid)
      order.update!(shipping_carrier_name: "Mondial Relay", shipping_method_name: "Point Relais")

      post create_shipment_admin_order_path(order)

      assert_redirected_to admin_order_path(order)
      shipment = order.reload.shipment
      assert_predicate shipment, :label_ready?
      assert_predicate shipment.label, :attached?

      get admin_order_path(order)
      assert_select "h2", text: "Expédition"
      assert_select "code", text: shipment.carrier_shipment_id
      assert_select "a", text: "Télécharger l’étiquette PDF"
      assert_select "form[action=?]", ship_admin_order_path(order)
    end

    test "does not create a shipment for a non-paid order" do
      sign_in_as(create_admin_user)
      order = create_paid_order(status: :pending)

      post create_shipment_admin_order_path(order)

      assert_redirected_to admin_order_path(order)
      assert_nil order.reload.shipment
      assert_match "payée", flash[:alert]
    end

    test "retries a failed shipment and uses its tracking to mark the order as shipped" do
      admin = create_admin_user
      sign_in_as(admin)
      order = create_paid_order(status: :paid)
      order.create_shipment!(carrier: "Mondial Relay", service: "Point Relais", status: :failed, error_message: "Indisponible")

      post retry_shipment_admin_order_path(order)

      shipment = order.reload.shipment
      assert_predicate shipment, :label_ready?

      patch ship_admin_order_path(order), params: { shipment: { use_created_shipment: "1" } }

      order.reload
      assert_predicate order, :shipped?
      assert_equal shipment.carrier, order.shipping_carrier
      assert_equal shipment.tracking_number, order.tracking_number
      assert_equal admin, order.order_status_events.last.admin_user
    end

    test "prepare transitions a paid order and shows the preparation action only while paid" do
      admin = create_admin_user
      sign_in_as(admin)
      order = create_paid_order(status: :paid)

      get admin_order_path(order)
      assert_select "form[action=?]", prepare_admin_order_path(order)
      assert_select "p", text: /Mise en préparation le/

      patch prepare_admin_order_path(order)

      assert_redirected_to admin_order_path(order)
      assert order.reload.preparing?
      assert_not_nil order.preparing_at
      assert_match "préparation", flash[:notice]

      get admin_order_path(order)
      assert_select "form[action=?]", prepare_admin_order_path(order), count: 0
      assert_select ".status-pill.preparing", text: "En préparation"
      assert_select "td", text: /Payée → En préparation/
    end

    test "ship refuses to transition a pending order" do
      sign_in_as(create_admin_user)
      order = create_paid_order(status: :pending)

      patch ship_admin_order_path(order), params: { shipment: { carrier_choice: "DHL", tracking_number: "JD0146000000" } }

      assert order.reload.pending?
    end

    test "shipping form is visible only while an order can be shipped" do
      admin = create_admin_user
      sign_in_as(admin)
      paid = create_paid_order(status: :paid)
      preparing = create_paid_order(status: :paid)
      preparing.mark_preparing!(admin_user: admin)
      shipped = create_paid_order(status: :shipped)

      get admin_order_path(paid)
      assert_select "form[action=?]", ship_admin_order_path(paid)
      assert_select "option", text: "Autre"

      get admin_order_path(preparing)
      assert_select "form[action=?]", ship_admin_order_path(preparing)

      get admin_order_path(shipped)
      assert_select "form[action=?]", ship_admin_order_path(shipped), count: 0
    end

    test "index displays translated order statuses while keeping technical filter values" do
      admin = create_admin_user
      sign_in_as(admin)
      order = create_paid_order(status: :paid)
      order.mark_preparing!(admin_user: admin)

      get admin_orders_path, params: { status: "preparing" }

      assert_select "option[value='preparing']", text: "En préparation"
      assert_select ".status-pill.preparing", text: "En préparation"
      assert_select "td", text: "preparing", count: 0
      assert_select "td", text: order.public_token.first(8).upcase
    end

    test "shipping with Autre uses the custom carrier name" do
      sign_in_as(create_admin_user)
      order = create_paid_order(status: :paid)

      patch ship_admin_order_path(order), params: { shipment: { carrier_choice: "other", shipping_carrier_other: "Transporteur local", tracking_number: "TRACK-42" } }

      assert order.reload.shipped?
      assert_equal "Transporteur local", order.shipping_carrier
    end

    test "prepare refuses a pending order" do
      sign_in_as(create_admin_user)
      order = create_paid_order(status: :pending)

      patch prepare_admin_order_path(order)

      assert order.reload.pending?
      assert_match "payée", flash[:alert]
    end
  end
end

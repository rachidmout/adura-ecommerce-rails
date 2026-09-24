require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  FakeCheckoutSession = Data.define(:id, :url, :expires_at)

  test "resume payment form disables Turbo for the external Stripe navigation" do
    order = create_paid_order(status: :pending)

    get order_confirmation_path(order.public_token, locale: nil)

    assert_response :success
    assert_select "form[data-turbo=false][action=?]", resume_order_path(order.public_token, locale: nil)
  end

  test "resuming a pending order redirects the browser to Stripe without a cart" do
    order = create_paid_order(status: :pending)
    with_fake_stripe_session do
      post resume_order_path(order.public_token, locale: nil)
    end

    assert_redirected_to "https://checkout.stripe.test/resume"
  end

  test "a cancelled Stripe return renders a safe payment retry page without changing the order" do
    order = create_paid_order(status: :pending)

    assert_no_changes -> { order.reload.status } do
      get order_confirmation_path(order.public_token, locale: nil), params: { cancelled: 1 }
    end

    assert_response :success
    assert_select "h1", "Paiement non finalisé"
    assert_select "p", "Votre paiement n’a pas été finalisé. Aucun prélèvement n’a été effectué."
    assert_select "form[data-turbo=false][action=?]", resume_order_path(order.public_token, locale: nil)
    assert_select "a.button.button-secondary[href=?]", cart_path(locale: nil), text: "Retour au panier"
    assert_select ".confirmation-summary h2", "Votre panier"
    assert_select ".confirmation[data-ecommerce-analytics-purchase-value]", count: 0
    assert_no_match(/Interrupted Title|Pending Text|Resume Cta|Summary/, response.body)
  end

  test "payment interruption translations exist in every public locale" do
    I18n.available_locales.each do |locale|
      %w[interrupted_title interrupted_text resume_cta back_to_cart cart_summary].each do |key|
        assert I18n.exists?("orders.show.#{key}", locale), "Missing #{key} for #{locale}"
      end
    end
  end

  test "paid confirmation exposes a purchase payload from immutable order snapshots" do
    order = create_paid_order(status: :paid)
    promo_code = create_promo_code(code: "PURCHASEPAYLOAD", discount_type: :percentage, discount_value: 10)
    item = order.order_items.first
    order.update!(
      promo_code: promo_code,
      shipping_cents: 490,
      discount_cents: 200,
      total_cents: item.line_total_cents + 490 - 200
    )

    get order_confirmation_path(order.public_token, locale: nil)

    element = Nokogiri::HTML(response.body).at_css(".confirmation[data-ecommerce-analytics-purchase-value]")
    payload_json = element["data-ecommerce-analytics-purchase-value"]
    payload = JSON.parse(payload_json)

    assert_equal order.public_token, payload.fetch("transaction_id")
    assert_equal "EUR", payload.fetch("currency")
    assert_equal order.total_cents / 100.0, payload.fetch("value")
    assert_equal 4.9, payload.fetch("shipping")
    assert_equal 2.0, payload.fetch("discount")
    assert_equal item.sku, payload.fetch("items").first.fetch("item_id")
    assert_equal item.product_name, payload.fetch("items").first.fetch("item_name")
    assert_equal item.brand_name, payload.fetch("items").first.fetch("item_brand")
    assert_equal item.variant_label, payload.fetch("items").first.fetch("item_variant")
    assert_equal item.unit_price_cents / 100.0, payload.fetch("items").first.fetch("price")
    assert_equal item.quantity, payload.fetch("items").first.fetch("quantity")
    assert_no_match(/client-test|0600000000|rue|75000|PURCHASEPAYLOAD/i, payload_json)
  end

  test "shipped confirmation also exposes a purchase payload with the same stable transaction id" do
    order = create_paid_order(status: :shipped)

    get order_confirmation_path(order.public_token, locale: nil)

    element = Nokogiri::HTML(response.body).at_css(".confirmation[data-ecommerce-analytics-purchase-value]")
    assert_equal order.public_token, JSON.parse(element["data-ecommerce-analytics-purchase-value"]).fetch("transaction_id")
  end

  test "unpaid, payment review, and cancelled confirmations never expose a purchase payload" do
    pending_order = create_paid_order(status: :pending)
    review_order = create_paid_order(status: :pending)
    review_order.update!(status: :payment_review)
    cancelled_order = create_paid_order(status: :pending)
    cancelled_order.update!(status: :cancelled)

    [ pending_order, review_order, cancelled_order ].each do |order|
      get order_confirmation_path(order.public_token, locale: nil)

      assert_select ".confirmation[data-ecommerce-analytics-purchase-value]", count: 0
    end
  end

  private

  def with_fake_stripe_session
    previous_key = ENV["STRIPE_SECRET_KEY"]
    original_create = Stripe::Checkout::Session.method(:create)
    ENV["STRIPE_SECRET_KEY"] = "test-key-placeholder"
    Stripe::Checkout::Session.define_singleton_method(:create) do |_params, _options|
      FakeCheckoutSession.new(id: "cs_test_turbo_resume", url: "https://checkout.stripe.test/resume", expires_at: 30.minutes.from_now.to_i)
    end
    yield
  ensure
    Stripe::Checkout::Session.define_singleton_method(:create, original_create) if original_create
    ENV["STRIPE_SECRET_KEY"] = previous_key
  end
end

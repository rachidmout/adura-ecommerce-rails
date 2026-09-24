require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  test "empty cart does not render the sticky checkout CTA" do
    get cart_path(locale: nil)

    assert_response :success
    assert_select ".cart-sticky-checkout", count: 0
    assert_select ".cart-empty a.button", text: "Découvrir les parfums"
  end

  test "cart renders the server total and sticky checkout CTA for cart lines" do
    product = create_publishable_product(slug: "mobile-cart-sticky")
    variant = product.product_variants.first
    post cart_items_path(locale: nil), params: { variant_id: variant.id, quantity: 1 }

    get cart_path(locale: nil)

    expected_total = variant.price_cents + ShopSetting.current.shipping_for(variant.price_cents)
    assert_response :success
    assert_select ".cart-sticky-checkout[data-analytics-hook='cart-checkout-cta'] strong", text: ApplicationController.helpers.money(expected_total)
    assert_select ".cart-sticky-checkout a[href=?][data-analytics-hook='cart-checkout-cta']", new_checkout_path(locale: nil), text: "Passer commande"
    assert_select "form[data-controller='cart-quantity'][data-analytics-hook='cart-quantity-control']"
    assert_select "button[data-cart-quantity-target='decrement']"
    assert_select "button[data-cart-quantity-target='increment']"
    assert_select "form.promo-code-form[data-analytics-hook='promo-code-form']"
    assert_select ".cart-item-image img[loading='lazy']"
    assert_select ".cart-item-image img[srcset]", count: 0
    assert_select "form.promo-code-form input[type='submit'].button.button-secondary[value='Appliquer']"
    assert_select "section.purchase-reassurance[aria-label='Les garanties ADURA'] li", count: 4
    assert_select "section.purchase-reassurance", text: /Paiement sécurisé.*Livraison suivie.*Expédition France & Europe.*Retours possibles sous 14 jours/
    assert_select "section.purchase-reassurance p", text: "Votre commande est préparée avec soin par ADURA."
  end

  test "cart quantity update and removal keep their existing routes" do
    product = create_publishable_product(slug: "mobile-cart-quantity")
    variant = product.product_variants.first
    post cart_items_path(locale: nil), params: { variant_id: variant.id, quantity: 1 }

    patch cart_item_path(variant, locale: nil), params: { quantity: 2 }
    assert_redirected_to cart_path(locale: nil)
    get cart_path(locale: nil)
    assert_select ".quantity-stepper select option[value='2'][selected='selected']"

    delete cart_item_path(variant, locale: nil)
    assert_redirected_to cart_path(locale: nil)
    get cart_path(locale: nil)
    assert_select ".cart-sticky-checkout", count: 0
  end

  test "cart mutation messages follow the Dutch public locale" do
    product = create_publishable_product(slug: "dutch-cart-messages")
    variant = product.product_variants.first

    post cart_items_path(locale: :nl), params: { variant_id: variant.id, quantity: 1 }
    assert_equal I18n.t("carts.messages.added", locale: :nl), flash[:notice]

    patch cart_item_path(variant, locale: :nl), params: { quantity: 2 }
    assert_equal I18n.t("carts.messages.updated", locale: :nl), flash[:notice]

    delete cart_item_path(variant, locale: :nl)
    assert_equal I18n.t("carts.messages.removed", locale: :nl), flash[:notice]
  end

  test "applied promo remains visible and updates the sticky server total" do
    product = create_publishable_product(slug: "mobile-cart-promo")
    variant = product.product_variants.first
    promo_code = create_promo_code(code: "MOBILE10", discount_type: :percentage, discount_value: 10)
    post cart_items_path(locale: nil), params: { variant_id: variant.id, quantity: 1 }
    post promo_code_path(locale: nil), params: { code: promo_code.code }

    get cart_path(locale: nil)

    discount = promo_code.discount_for(variant.price_cents)
    expected_total = variant.price_cents + ShopSetting.current.shipping_for(variant.price_cents) - discount
    assert_select ".promo-code-active", text: /MOBILE10/
    assert_select ".cart-sticky-checkout strong", text: ApplicationController.helpers.money(expected_total)
  end

  test "cart analytics uses server cart lines and never exposes the promo code" do
    product = create_publishable_product(slug: "analytics-cart")
    variant = product.product_variants.first
    promo_code = create_promo_code(code: "ANALYTICSPROMO", discount_type: :percentage, discount_value: 10)
    post cart_items_path(locale: nil), params: { variant_id: variant.id, quantity: 2 }
    post promo_code_path(locale: nil), params: { code: promo_code.code }

    get cart_path(locale: nil)

    element = Nokogiri::HTML(response.body).at_css(".cart-page[data-ecommerce-analytics-view-cart-value]")
    payload = JSON.parse(element["data-ecommerce-analytics-view-cart-value"])
    promo_json = element["data-ecommerce-analytics-promo-value"]
    promo_payload = JSON.parse(promo_json)

    assert_equal variant.price_cents * 2 / 100.0, payload.fetch("value")
    assert_equal 2, payload.fetch("items").first.fetch("quantity")
    assert_equal variant.sku, payload.fetch("items").first.fetch("item_id")
    assert_equal true, promo_payload.fetch("promo_applied")
    assert_equal "percentage", promo_payload.fetch("discount_type")
    assert_no_match promo_code.code, promo_json
    assert_select "form[data-action='submit->ecommerce-analytics#removeFromCart'][data-ecommerce-analytics-item]"
  end

  test "shipping feature shows a neutral delivery message and excludes legacy shipping from cart totals" do
    product = create_publishable_product(slug: "cart-shipping-feature", price_cents: 2_000)
    variant = product.product_variants.first
    ShopSetting.current.update!(shipping_rate_cents: 490)
    post cart_items_path(locale: nil), params: { variant_id: variant.id, quantity: 1 }

    with_shipping_methods_feature { get cart_path(locale: nil) }

    assert_response :success
    assert_select ".order-summary dt", text: "Total hors livraison"
    assert_select ".order-summary dd", text: "Calculée au checkout"
    assert_select ".cart-sticky-checkout span", text: I18n.t("order_summary.total_excluding_shipping")
    assert_select ".cart-sticky-checkout strong", text: ApplicationController.helpers.money(variant.price_cents)
    assert_no_match ApplicationController.helpers.money(variant.price_cents + 490), response.body
  end

  test "reassurance labels are translated in every supported locale" do
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        %i[title secure_payment tracked_delivery shipping_area returns note].each do |key|
          assert I18n.exists?("purchase_reassurance.#{key}", locale), "#{locale}: #{key}"
        end
      end
    end
  end

  private

  def with_shipping_methods_feature
    previous_value = ENV["CHECKOUT_SHIPPING_METHODS_ENABLED"]
    ENV["CHECKOUT_SHIPPING_METHODS_ENABLED"] = "true"
    yield
  ensure
    ENV["CHECKOUT_SHIPPING_METHODS_ENABLED"] = previous_value
  end
end

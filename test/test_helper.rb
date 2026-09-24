ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    ADMIN_TEST_PASSWORD = "Test-Password-123456"

    def create_admin_user(email: "admin-test@adura.local")
      AdminUser.create!(email: email, password: ADMIN_TEST_PASSWORD, password_confirmation: ADMIN_TEST_PASSWORD, active: true)
    end

    # Utilisable uniquement depuis un test d'intégration/contrôleur (a besoin
    # de `post`, absent des tests de modèle) : connecte l'admin passé en
    # paramètre via le vrai flux de connexion (pas un raccourci sur la
    # session), pour que les tests couvrent le même chemin qu'un utilisateur.
    def sign_in_as(admin_user)
      post admin_login_path, params: { email: admin_user.email, password: ADMIN_TEST_PASSWORD }
    end

    def create_paid_order(variant: nil, status: :paid)
      variant ||= create_publishable_product(slug: "test-parfum-#{SecureRandom.hex(4)}").product_variants.first
      order = Order.create!(
        status: "pending", email: "client-test@example.com", first_name: "Test", last_name: "Client", phone: "0600000000",
        address_line1: "1 rue de Test", postal_code: "75000", city: "Paris", country_code: "FR", currency: "EUR",
        shipping_rate_snapshot_cents: 490, subtotal_cents: 0, shipping_cents: 0, total_cents: 0,
        terms_accepted_at: Time.current
      )
      order.order_items.create!(
        product_variant: variant, product_name: variant.product.name, brand_name: variant.product.brand.name,
        variant_label: variant.label, sku: variant.sku, volume_ml: variant.volume_ml,
        unit_price_cents: variant.price_cents, quantity: 1, line_total_cents: variant.price_cents
      )
      order.update!(subtotal_cents: variant.price_cents, shipping_cents: 490, total_cents: variant.price_cents + 490)
      order.update!(status: status, paid_at: Time.current) if status.to_s.in?(%w[paid shipped])
      order
    end

    def create_promo_code(code: "TEST#{SecureRandom.hex(3).upcase}", discount_type: :percentage, discount_value: 10, **attrs)
      PromoCode.create!(code: code, discount_type: discount_type, discount_value: discount_value, active: true, **attrs)
    end

    def create_publishable_product(slug: "test-parfum", price_cents: 2_000, stock_quantity: 5, family_slug: "gourmand", audience: "unisex")
      brand = Brand.find_or_create_by!(slug: "test-brand") { |record| record.name = "Test Brand" }
      family = OlfactoryFamily.find_or_create_by!(slug: family_slug) { |record| record.name = family_slug.humanize }
      product = Product.create!(
        brand: brand,
        name: slug.humanize,
        slug: slug,
        short_description: "Description courte de test",
        description: "Description complète et vérifiée pour le test.",
        source_urls: [ "https://example.com/#{slug}" ],
        verified_at: Time.current,
        status: :draft
      )
      product.create_perfume_profile!(audience: audience, intensity_level: "moderate", occasion_codes: [ "daily" ])
      ProductOlfactoryFamily.create!(product: product, olfactory_family: family, role: :primary)
      product.product_variants.create!(sku: "SKU-#{slug.upcase}", volume_ml: 100, price_cents: price_cents, stock_quantity: stock_quantity, currency: "EUR", active: true)
      image = product.product_images.create!(alt_text: "Flacon de test", primary: true)
      image.file.attach(io: File.open(file_fixture("bottle.jpg")), filename: "bottle.jpg", content_type: "image/jpeg")
      product.publish!
      product
    end
  end
end

module Shipping
  class QuoteCalculator
    class Error < StandardError; end
    class DestinationUnsupported < Error; end
    class MissingVariantWeight < Error; end
    class NoShippingMethodAvailable < Error; end
    class NoRateForWeight < Error; end
    class InvalidCartLine < Error; end
    class ShippingConfigurationError < Error; end

    MethodQuote = Data.define(
      :shipping_method_id,
      :shipping_zone_name,
      :name,
      :carrier_name,
      :kind,
      :provider,
      :provider_carrier_code,
      :shipping_rate_id,
      :free_shipping_threshold_cents,
      :normal_price_cents,
      :price_cents,
      :free_shipping
    )
    Quote = Data.define(:package_weight_grams, :country_code, :shipping_zone_id, :methods)

    def initialize(country_code:, lines:, subtotal_cents:, shop_setting: nil)
      @country_code = country_code.to_s.strip.upcase
      @lines = lines
      @subtotal_cents = subtotal_cents
    end

    def call
      validate_subtotal!
      normalized_lines = load_and_validate_lines
      package_weight = normalized_lines.sum { |line| line.fetch(:variant).shipping_weight_grams * line.fetch(:quantity) }
      zone = destination_zone!
      methods = method_quotes_for(zone, package_weight)

      Quote.new(package_weight, country_code, zone.id, methods)
    end

    private

    attr_reader :country_code, :lines, :subtotal_cents

    def validate_subtotal!
      return if subtotal_cents.is_a?(Integer) && subtotal_cents >= 0

      raise InvalidCartLine, "Le sous-total doit être un montant positif ou nul en centimes."
    end

    def load_and_validate_lines
      raise InvalidCartLine, "Les lignes du panier sont invalides." unless lines.respond_to?(:each)

      requested_lines = lines.map do |line|
        variant_id = line.variant.id if line.respond_to?(:variant) && line.variant
        quantity = line.quantity if line.respond_to?(:quantity)
        raise InvalidCartLine, "Une ligne du panier est invalide." unless variant_id && quantity.is_a?(Integer) && quantity.positive?

        { variant_id: variant_id, quantity: quantity }
      end
      raise InvalidCartLine, "Le panier ne contient aucune ligne." if requested_lines.empty?

      variants_by_id = ProductVariant.where(id: requested_lines.map { |line| line.fetch(:variant_id) }).index_by(&:id)
      quantities_by_variant_id = requested_lines.each_with_object(Hash.new(0)) { |line, quantities| quantities[line.fetch(:variant_id)] += line.fetch(:quantity) }

      quantities_by_variant_id.map do |variant_id, quantity|
        variant = variants_by_id.fetch(variant_id) { raise InvalidCartLine, "Une variante du panier n’existe plus." }
        raise MissingVariantWeight, "Le poids expédié de #{variant.sku} doit être renseigné." unless variant.shipping_weight_grams.present?

        { variant: variant, quantity: quantity }
      end
    end

    def destination_zone!
      country = ShippingZoneCountry.includes(shipping_zone: { shipping_methods: :shipping_rates }).find_by(country_code: country_code)
      raise DestinationUnsupported, "Cette destination n’est pas desservie." unless country&.shipping_zone&.active?

      country.shipping_zone
    end

    def method_quotes_for(zone, package_weight)
      active_methods = zone.shipping_methods.select(&:active?)
      raise NoShippingMethodAvailable, "Aucune méthode de livraison active n’est disponible." if active_methods.empty?

      quotes = active_methods.filter_map { |shipping_method| quote_for_method(shipping_method, zone, package_weight) }
      raise NoRateForWeight, "Aucun tarif de livraison ne couvre ce poids." if quotes.empty?

      quotes
    end

    def quote_for_method(shipping_method, zone, package_weight)
      matching_rates = shipping_method.shipping_rates.select do |rate|
        rate.active? && rate.min_weight_grams <= package_weight && (rate.max_weight_grams.nil? || rate.max_weight_grams >= package_weight)
      end
      return if matching_rates.empty?
      raise ShippingConfigurationError, "Plusieurs tranches couvrent le même poids pour #{shipping_method.name}." if matching_rates.many?

      rate = matching_rates.first
      free_shipping = shipping_method.free_shipping_threshold_cents.present? && subtotal_cents >= shipping_method.free_shipping_threshold_cents
      MethodQuote.new(
        shipping_method.id,
        zone.name,
        shipping_method.name,
        shipping_method.carrier_name,
        shipping_method.kind,
        shipping_method.provider,
        shipping_method.provider_carrier_code,
        rate.id,
        shipping_method.free_shipping_threshold_cents,
        rate.price_cents,
        free_shipping ? 0 : rate.price_cents,
        free_shipping
      )
    end
  end
end

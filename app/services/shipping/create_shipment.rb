require "stringio"

module Shipping
  class CreateShipment
    class Error < StandardError; end
    class InvalidOrder < Error; end
    class AlreadyCreated < Error; end
    class InProgress < Error; end
    class Unavailable < Error; end

    def initialize(order:, client: nil)
      @order = order
      @client = client
    end

    def call
      shipment = prepare_shipment!
      result = client.create(order: order)
      persist_result!(shipment, result)
    rescue Carriers::BaseShipmentClient::Unavailable => error
      fail_shipment!(shipment, error.message)
      raise Unavailable, error.message
    rescue StandardError => error
      raise if error.is_a?(Error)

      Rails.logger.error("Création d’expédition impossible pour la commande #{order.id}: #{error.class}")
      fail_shipment!(shipment, "La création de l’expédition a échoué. Réessayez dans quelques instants.")
      raise Unavailable, "La création de l’expédition a échoué. Réessayez dans quelques instants."
    end

    private

    attr_reader :order

    def prepare_shipment!
      Shipment.transaction do
        order.lock!
        raise InvalidOrder, "Seule une commande payée ou en préparation peut être expédiée." unless order.paid? || order.preparing?

        shipment = order.shipment || order.build_shipment(carrier: carrier_name, service: service_name)
        raise AlreadyCreated, "Une expédition existe déjà pour cette commande." if shipment.ready?
        raise InProgress, "La création de l’expédition est déjà en cours." if shipment.persisted? && shipment.pending?

        shipment.assign_attributes(
          carrier: carrier_name,
          service: service_name,
          status: :pending,
          carrier_shipment_id: nil,
          tracking_number: nil,
          tracking_url: nil,
          label_url: nil,
          error_message: nil,
          raw_response: {}
        )
        shipment.save!
        shipment
      end
    end

    def persist_result!(shipment, result)
      Shipment.transaction do
        shipment.lock!
        shipment.assign_attributes(
          carrier: result.carrier,
          service: result.service,
          carrier_shipment_id: result.carrier_shipment_id,
          tracking_number: result.tracking_number,
          tracking_url: result.tracking_url,
          label_url: result.label_url,
          raw_response: result.raw_response || {},
          error_message: nil,
          status: result.label_data.present? || result.label_url.present? ? :label_ready : :created
        )
        attach_label!(shipment, result)
        shipment.save!
        shipment
      end
    end

    def fail_shipment!(shipment, message)
      return unless shipment&.persisted?

      shipment.with_lock do
        shipment.update!(status: :failed, error_message: message, carrier_shipment_id: nil, tracking_number: nil, tracking_url: nil, label_url: nil, raw_response: {})
      end
    end

    def attach_label!(shipment, result)
      return if result.label_data.blank?

      shipment.label.attach(
        io: StringIO.new(result.label_data),
        filename: result.label_filename.presence || "etiquette-#{shipment.order.public_token.first(8)}.pdf",
        content_type: "application/pdf"
      )
    end

    def client
      return @client if @client
      return Carriers::FakeShipmentClient.new unless Rails.env.production?
      return sendcloud_client if shipping_provider == "sendcloud"

      unless carrier_name == "Mondial Relay"
        raise Unavailable, "La création d’expédition automatique n’est pas encore configurée pour #{carrier_name}."
      end
      raise Unavailable, "La création d’expédition Mondial Relay n’est pas encore configurée." unless Carriers::MondialRelayShipmentClient.configured?

      Carriers::MondialRelayShipmentClient.new
    end

    def carrier_name
      order.shipping_carrier_name.presence || order.relay_point&.carrier.presence || "Transporteur"
    end

    def service_name
      order.shipping_method_name.presence || "Livraison standard"
    end

    def shipping_provider
      order.shipping_provider.presence || "direct"
    end

    def sendcloud_client
      raise Unavailable, "La création d’expédition Sendcloud n’est pas configurée." unless Carriers::SendcloudShipmentClient.configured?

      Carriers::SendcloudShipmentClient.new(
        carrier_code: order.shipping_provider_carrier_code,
        delivery_kind: order.shipping_method_kind,
        method_id_override: current_sendcloud_method_override
      )
    end

    def current_sendcloud_method_override
      methods = ShippingMethod.where(
        provider: "sendcloud",
        name: order.shipping_method_name,
        provider_carrier_code: order.shipping_provider_carrier_code
      )
      methods = methods.joins(:shipping_zone).where(shipping_zones: { name: order.shipping_zone_name }) if order.shipping_zone_name.present?
      methods.first&.provider_method_id_override
    end
  end
end

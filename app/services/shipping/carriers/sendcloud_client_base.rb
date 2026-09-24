require "json"
require "net/http"
require "uri"

module Shipping
  module Carriers
    class SendcloudClientBase
      class Error < StandardError; end
      class Unavailable < Error; end
      class NotFound < Error; end

      PANEL_BASE_URL = "https://panel.sendcloud.sc/api/v2".freeze
      SERVICE_POINTS_BASE_URL = "https://servicepoints.sendcloud.sc/api/v2".freeze
      MAX_REDIRECTS = 3

      def self.configured?
        ENV["SENDCLOUD_PUBLIC_KEY"].present? && ENV["SENDCLOUD_SECRET_KEY"].present?
      end

      def initialize(public_key: ENV["SENDCLOUD_PUBLIC_KEY"], secret_key: ENV["SENDCLOUD_SECRET_KEY"], panel_base_url: ENV.fetch("SENDCLOUD_API_BASE_URL", PANEL_BASE_URL), service_points_base_url: SERVICE_POINTS_BASE_URL)
        @public_key = public_key.to_s.strip
        @secret_key = secret_key.to_s.strip
        @panel_base_url = URI(panel_base_url)
        @service_points_base_url = URI(service_points_base_url)
      end

      attr_reader :panel_base_url, :service_points_base_url

      def get_json(base_url, path, params: {})
        request_json(Net::HTTP::Get, build_uri(base_url, path, params))
      end

      def post_json(base_url, path, payload:)
        request_json(Net::HTTP::Post, build_uri(base_url, path), payload: payload)
      end

      def get_pdf(base_url, path)
        ensure_configured!
        uri = build_uri(base_url, path)
        request = Net::HTTP::Get.new(uri)
        request.basic_auth(public_key, secret_key)
        response = perform_json_request(request_class, uri, payload:)
        return unless response.is_a?(Net::HTTPSuccess)

        data = response.body.to_s
        return unless response["Content-Type"].to_s.include?("pdf") || data.start_with?("%PDF-")

        data
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError => error
        Rails.logger.warn("Sendcloud étiquette indisponible: #{error.class}")
        nil
      end

      private

      attr_reader :public_key, :secret_key

      def ensure_configured!
        return if public_key.present? && secret_key.present?

        raise Unavailable, "L’intégration Sendcloud n’est pas configurée."
      end

      def request_json(request_class, uri, payload: nil)
        ensure_configured!
        response = perform_json_request(request_class, uri, payload:)
        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        when Net::HTTPBadRequest
          Rails.logger.warn("Sendcloud rejected request: status=#{response.code} path=#{uri.path}")
          raise Unavailable, "Sendcloud a refusé cette demande. Vérifiez que les points relais et le transporteur sont activés dans votre intégration Sendcloud."
        when Net::HTTPNotFound
          Rails.logger.warn("Sendcloud endpoint not found: status=#{response.code} path=#{uri.path}")
          raise NotFound, "La ressource Sendcloud demandée est introuvable."
        when Net::HTTPUnauthorized, Net::HTTPForbidden
          Rails.logger.warn("Sendcloud access denied: status=#{response.code} path=#{uri.path}")
          raise Unavailable, "L’intégration Sendcloud refuse l’accès. Vérifiez ses identifiants et autorisations."
        else
          Rails.logger.warn("Sendcloud unavailable: status=#{response.code} path=#{uri.path}")
          raise Unavailable, "Le service Sendcloud est momentanément indisponible."
        end
      rescue JSON::ParserError
        raise Unavailable, "Sendcloud a retourné une réponse invalide."
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError => error
        Rails.logger.warn("Sendcloud indisponible: #{error.class}")
        raise Unavailable, "Le service Sendcloud est momentanément indisponible."
      end

      def build_uri(base_url, path, params = {})
        uri = base_url.dup
        uri.path = [ uri.path.delete_suffix("/"), path.delete_prefix("/") ].join("/")
        uri.query = URI.encode_www_form(params.compact) if params.any?
        uri
      end

      def perform_request(uri, request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 4, read_timeout: 12) { |http| http.request(request) }
      end

      def perform_json_request(request_class, uri, payload:, redirects: 0)
        request = request_class.new(uri)
        request.basic_auth(public_key, secret_key)
        request["Accept"] = "application/json"
        if payload
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(payload)
        end
        response = perform_request(uri, request)
        return response unless response.is_a?(Net::HTTPRedirection)

        raise Unavailable, "Sendcloud a renvoyé trop de redirections." if redirects >= MAX_REDIRECTS
        raise Unavailable, "Sendcloud a renvoyé une redirection non sûre." unless request_class == Net::HTTP::Get && payload.nil?

        redirected_uri = redirect_uri(uri, response["location"])
        Rails.logger.info("Following Sendcloud redirect: status=#{response.code} path=#{uri.path}")
        perform_json_request(request_class, redirected_uri, payload:, redirects: redirects + 1)
      end

      def redirect_uri(uri, location)
        redirected_uri = URI.join(uri.to_s, location.to_s)
        redirected_uri.query ||= uri.query
        return redirected_uri if redirected_uri.is_a?(URI::HTTPS) && redirected_uri.host == uri.host

        raise Unavailable, "Sendcloud a renvoyé une redirection non sûre."
      rescue URI::InvalidURIError
        raise Unavailable, "Sendcloud a renvoyé une redirection invalide."
      end
    end
  end
end

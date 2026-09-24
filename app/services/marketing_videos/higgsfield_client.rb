require "json"
require "erb"
require "net/http"
require "uri"

module MarketingVideos
  class HiggsfieldClient
    BASE_URL = "https://platform.higgsfield.ai"
    IMAGE_TO_VIDEO_ENDPOINT = "/v1/image2video/dop"
    SUPPORTED_MODELS = %w[dop-lite dop-turbo dop-standard].freeze
    DEFAULT_MODEL = "dop-turbo"
    DEFAULT_TIMEOUT_SECONDS = 20

    class Error < StandardError; end
    class Disabled < Error; end
    class CredentialsMissing < Error; end
    class ConfigurationError < Error; end
    class DiagnosticError < Error
      attr_reader :diagnostics

      def initialize(message, diagnostics: {})
        super(message)
        @diagnostics = diagnostics
      end
    end

    class ResponseError < DiagnosticError; end
    class InvalidResponse < DiagnosticError; end
    Response = Data.define(:status, :request_id, :status_url, :cancel_url, :video_url, :raw_response)
    ResponsePayload = Data.define(:payload, :diagnostics)

    class << self
      def enabled?
        ActiveModel::Type::Boolean.new.cast(ENV.fetch("HIGGSFIELD_ENABLED", false))
      end

      def configured?
        credentials_valid?(ENV["HIGGSFIELD_CREDENTIALS"]) && supported_model?(ENV.fetch("HIGGSFIELD_MODEL", DEFAULT_MODEL))
      end

      private

      def credentials_valid?(credentials)
        credentials.to_s.match?(/\A[^:\s]+:[^:\s]+\z/)
      end

      def supported_model?(model)
        model.in?(SUPPORTED_MODELS)
      end
    end

    def initialize(credentials: ENV["HIGGSFIELD_CREDENTIALS"], model: ENV.fetch("HIGGSFIELD_MODEL", DEFAULT_MODEL), timeout_seconds: ENV.fetch("HIGGSFIELD_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS))
      raise Disabled, "La génération Higgsfield est désactivée." unless self.class.enabled?
      raise CredentialsMissing, "Les identifiants Higgsfield sont absents ou invalides." unless credentials.to_s.match?(/\A[^:\s]+:[^:\s]+\z/)
      raise ConfigurationError, "Le modèle Higgsfield configuré n’est pas compatible avec la génération image-vers-vidéo." unless model.in?(SUPPORTED_MODELS)

      @credentials = credentials
      @model = model
      @timeout_seconds = Integer(timeout_seconds, exception: false).to_i.clamp(5, 120)
    end

    def submit(video_job)
      response_from(request(:post, IMAGE_TO_VIDEO_ENDPOINT, {
        params: {
          model: @model,
          prompt: video_job.higgsfield_prompt,
          input_images: [ { type: "image_url", image_url: video_job.reference_image_url } ]
        }
      }))
    end

    def status(request_id)
      raise InvalidResponse, "Higgsfield n’a pas retourné d’identifiant de demande." if request_id.blank?

      response_from(request(:get, "/requests/#{ERB::Util.url_encode(request_id)}/status"))
    end

    private

    def request(method, path, body = nil)
      uri = URI.join(BASE_URL, path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = @timeout_seconds
      http.read_timeout = @timeout_seconds

      request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      request["Authorization"] = "Key #{@credentials}"
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "ADURA marketing video worker"
      request.body = JSON.generate(body) if body

      response = http.request(request)
      return response_payload_for(response) if response.is_a?(Net::HTTPSuccess)

      raise response_error_for(response)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, EOFError
      raise ResponseError, "Higgsfield est momentanément indisponible."
    end

    def parse_response(body)
      JSON.parse(body)
    end

    def response_payload_for(response)
      ResponsePayload.new(
        payload: parse_response(response.body),
        diagnostics: success_diagnostics_for(response)
      )
    rescue JSON::ParserError
      raise InvalidResponse.new("Higgsfield a retourné une réponse invalide.", diagnostics: success_diagnostics_for(response))
    end

    def success_diagnostics_for(response)
      {
        "provider" => "higgsfield",
        "http_status" => response.code.to_i,
        "response_body" => sanitized_error_body(response.body),
        "parsed_response" => parsed_error_body(response.body),
        "response_headers" => useful_response_headers(response)
      }.compact
    end

    def response_error_for(response)
      ResponseError.new(
        error_message_for(response.code),
        diagnostics: {
          "provider" => "higgsfield",
          "http_status" => response.code.to_i,
          "error_body" => sanitized_error_body(response.body),
          "parsed_error" => parsed_error_body(response.body),
          "response_headers" => useful_response_headers(response)
        }.compact
      )
    end

    def parsed_error_body(body)
      sanitize_diagnostic_value(JSON.parse(body))
    rescue JSON::ParserError
      nil
    end

    def sanitized_error_body(body)
      value = body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")
      value = value.first(10_000) + "…" if value.length > 10_000

      parsed_value = JSON.parse(value)
      JSON.generate(sanitize_diagnostic_value(parsed_value)).presence
    rescue JSON::ParserError
      redact_sensitive_value(value).presence
    end

    def useful_response_headers(response)
      headers = {}
      response.each_header do |name, value|
        headers[name] = redact_sensitive_value(value) if name.in?(%w[content-type x-request-id request-id])
      end
      headers.presence
    end

    def sanitize_diagnostic_value(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, item), sanitized|
          sanitized[key] = sensitive_key?(key) ? "[REDACTED]" : sanitize_diagnostic_value(item)
        end
      when Array
        value.map { |item| sanitize_diagnostic_value(item) }
      when String
        redact_sensitive_value(value)
      else
        value
      end
    end

    def sensitive_key?(key)
      key.to_s.match?(/authorization|credential|password|secret|token|api[_-]?key|private[_-]?key/i)
    end

    def redact_sensitive_value(value)
      credentials = @credentials.to_s
      redacted_value = value.to_s
      redacted_value = redacted_value.gsub(credentials, "[REDACTED]") if credentials.present?
      redacted_value.gsub(/((?:authorization|credential|password|secret|token|api[_-]?key|private[_-]?key)[^:=\r\n]*[=:]\s*)[^\r\n]+/i, "\\1[REDACTED]")
    end

    def response_from(response_payload)
      payload = response_payload.payload
      request_id = payload["id"].presence || payload["request_id"].presence
      status = payload["status"].presence || payload.dig("jobs", 0, "status").presence || "queued"
      raise KeyError if request_id.blank?

      video_url = payload.dig("video", "url")

      Response.new(
        status: status,
        request_id: request_id,
        status_url: payload["status_url"],
        cancel_url: payload["cancel_url"],
        video_url: video_url,
        raw_response: sanitized_response(payload)
      )
    rescue KeyError
      raise InvalidResponse.new("Higgsfield a retourné une réponse incomplète.", diagnostics: response_payload.diagnostics)
    end

    def sanitized_response(payload)
      sanitize_diagnostic_value(payload).merge(
        "higgsfield_request_id" => payload["id"].presence || payload["request_id"].presence,
        "higgsfield_child_job_id" => payload.dig("jobs", 0, "id"),
        "initial_provider_status" => payload["status"].presence || payload.dig("jobs", 0, "status")
      ).compact
    end

    def error_message_for(status_code)
      case status_code.to_i
      when 401 then "Higgsfield a refusé les identifiants configurés."
      when 403 then "Higgsfield a refusé la génération ou les crédits sont indisponibles."
      when 400, 422 then "La demande envoyée à Higgsfield est invalide."
      else "Higgsfield a répondu avec une erreur (#{status_code})."
      end
    end
  end
end

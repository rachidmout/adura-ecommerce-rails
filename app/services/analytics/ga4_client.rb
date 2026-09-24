require "google/analytics/data/v1beta"

module Analytics
  class Ga4Client
    class Unavailable < StandardError; end

    attr_reader :property_id

    def initialize(property_id: ENV["GA4_PROPERTY_ID"], credentials_path: ENV["GOOGLE_APPLICATION_CREDENTIALS"], client: nil)
      @property_id = property_id.to_s.strip
      @credentials_path = credentials_path.to_s.strip
      @client = client
    end

    def configured?
      property_id.match?(/\A\d+\z/) && credentials_path.present? && (client_provided? || File.file?(credentials_path))
    end

    def run_report(dimensions:, metrics:, start_date:, end_date:, event_names: nil, limit: 10)
      request = Google::Analytics::Data::V1beta::RunReportRequest.new(
        property: "properties/#{property_id}",
        date_ranges: [ Google::Analytics::Data::V1beta::DateRange.new(start_date: start_date.iso8601, end_date: end_date.iso8601) ],
        dimensions: dimensions.map { |name| Google::Analytics::Data::V1beta::Dimension.new(name: name) },
        metrics: metrics.map { |name| Google::Analytics::Data::V1beta::Metric.new(name: name) },
        dimension_filter: event_filter(event_names),
        limit: limit
      )

      normalize_response(api_client.run_report(request, timeout: 5), dimensions, metrics)
    rescue StandardError => error
      Rails.logger.warn("GA4 Data API unavailable: #{error.class}")
      raise Unavailable, "GA4 Data API unavailable"
    end

    private

    attr_reader :credentials_path

    def client_provided?
      @client.present?
    end

    def api_client
      @client ||= Google::Analytics::Data::V1beta::AnalyticsData::Client.new
    end

    def event_filter(event_names)
      return if event_names.blank?

      Google::Analytics::Data::V1beta::FilterExpression.new(
        filter: Google::Analytics::Data::V1beta::Filter.new(
          field_name: "eventName",
          in_list_filter: Google::Analytics::Data::V1beta::Filter::InListFilter.new(values: event_names)
        )
      )
    end

    def normalize_response(response, dimensions, metrics)
      response.rows.map do |row|
        dimensions.zip(row.dimension_values).to_h { |name, value| [ name, value.value ] }
                  .merge(metrics.zip(row.metric_values).to_h { |name, value| [ name, value.value ] })
      end
    end
  end
end

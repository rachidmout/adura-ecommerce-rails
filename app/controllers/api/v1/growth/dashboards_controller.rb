module Api
  module V1
    module Growth
      class DashboardsController < ApplicationController
        before_action :authenticate_growth_api!
        before_action :validate_period!

        rescue_from StandardError, with: :render_internal_error

        def show
          local_report = Analytics::LocalDashboard.new(period: requested_period).call
          ga4_report = Analytics::Ga4Dashboard.new(period: local_report.period).call
          insights = Analytics::DashboardInsights.new(ga4_report: ga4_report).call

          render json: Analytics::GrowthDashboardPayload.new(
            local_report: local_report,
            ga4_report: ga4_report,
            insights: insights
          ).as_json
        end

        private

        def authenticate_growth_api!
          expected_token = ENV.fetch("ADURA_GROWTH_API_TOKEN", "")
          provided_token = bearer_token
          return if expected_token.present? && provided_token.present? && secure_token_match?(provided_token, expected_token)

          render json: { error: "unauthorized" }, status: :unauthorized
        end

        def validate_period!
          return if performed? || Analytics::LocalDashboard.valid_period?(requested_period)

          render json: { error: "invalid_period" }, status: :bad_request
        end

        def requested_period
          params.fetch(:period, "7d")
        end

        def bearer_token
          authorization = request.authorization.to_s
          return unless authorization.match?(/\ABearer\s+\S+\z/)

          authorization.delete_prefix("Bearer ").strip
        end

        def secure_token_match?(provided_token, expected_token)
          return false unless provided_token.bytesize == expected_token.bytesize

          ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
        end

        def render_internal_error(error)
          Rails.logger.error("Growth dashboard API error: #{error.class}")
          render json: { error: "internal_error" }, status: :internal_server_error unless performed?
        end
      end
    end
  end
end

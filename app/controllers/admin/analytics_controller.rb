module Admin
  class AnalyticsController < BaseController
    def show
      @report = Analytics::LocalDashboard.new(period: params[:period]).call
      @ga4_report = Analytics::Ga4Dashboard.new(period: @report.period).call
      @insights = Analytics::DashboardInsights.new(ga4_report: @ga4_report).call
    end
  end
end

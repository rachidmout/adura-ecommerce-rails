class StaticPagesController < ApplicationController
  PAGES = %w[about faq contact shipping returns terms privacy legal].freeze

  def show
    raise ActionController::RoutingError, "Not Found" unless PAGES.include?(params[:page])

    render params[:page]
  end
end

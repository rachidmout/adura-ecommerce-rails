class CommercialPagesController < ApplicationController
  def show
    @commercial_page = Catalog::CommercialPage.find(params[:page_key])
    raise ActiveRecord::RecordNotFound unless @commercial_page

    @products = @commercial_page.products
    raise ActiveRecord::RecordNotFound if @products.empty?

    @related_families = @commercial_page.related_families
  end
end

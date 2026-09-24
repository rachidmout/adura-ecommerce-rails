class AddressLookupsController < ApplicationController
  def cities
    cities = if params[:country_code].to_s.upcase == "FR" && params[:postal_code].to_s.match?(/\A\d{5}\z/)
      AddressLookup::France.cities_for(params[:postal_code])
    else
      []
    end

    render json: { cities: cities }
  end
end

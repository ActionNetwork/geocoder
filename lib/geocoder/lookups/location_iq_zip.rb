require 'geocoder/lookups/nominatim'
require "geocoder/results/location_iq_zip"

module Geocoder::Lookup
  class LocationIqZip < Nominatim
    def name
      "LocationIqZip"
    end

    def required_api_key_parts
      ["api_key"]
    end

    private # ----------------------------------------------------------------

    def base_query_url(query)
      method = query.reverse_geocode? ? "reverse" : "search/postalcode"
      "#{protocol}://#{configured_host}/v1/#{method}/?"
    end

    def query_url_params(query)
      params = {
        :format => "json",
        :key => configuration.api_key
      }.merge(super)
      if query.reverse_geocode?
        lat,lon = query.coordinates
        params[:lat] = lat
        params[:lon] = lon
      else
        params[:postalcode] = query.sanitized_text
      end
      params
    end

    def configured_host
      configuration[:host] || "locationiq.org"
    end

    def results(query)
      return [] unless doc = fetch_data(query)

      if !doc.is_a?(Array)
        case doc['error']
        when "Invalid key"
          raise_error(Geocoder::InvalidApiKey, doc['error'])
        when "Key not active - Please write to contact@unwiredlabs.com"
          raise_error(Geocoder::RequestDenied, doc['error'])
        when "Rate Limited"
          raise_error(Geocoder::OverQueryLimitError, doc['error'])
        when "Unknown error - Please try again after some time"
          raise_error(Geocoder::InvalidRequest, doc['error'])
        end
      end

      doc.is_a?(Array) ? doc : [doc]
    end
  end
end

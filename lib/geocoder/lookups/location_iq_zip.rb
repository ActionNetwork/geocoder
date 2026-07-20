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
      params[:q] = nil
      params
    end

    def configured_host
      configuration[:host] || "locationiq.org"
    end

    # Normally only 2xx-3xx responses are cached. A 404 with the specific
    # "Unable to geocode" body means the postal code is definitively
    # unknown, so it's safe (and desirable) to cache that. Other 404 bodies
    # and other non-2xx codes (5xx, timeouts, etc) are left uncached since
    # they may indicate a transient issue rather than an unknown zip.
    def valid_response?(response)
      super || (response.code.to_i == 404 && unable_to_geocode?(response.body))
    end

    def unable_to_geocode?(body)
      JSON.parse(body)['error'] == "Unable to geocode"
    rescue JSON::ParserError
      false
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

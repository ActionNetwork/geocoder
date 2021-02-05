require 'geocoder/lookups/base'
require 'geocoder/results/pelias_zip'

module Geocoder::Lookup
  class PeliasZip < Base
    def name
      'PeliasZip'
    end

    def endpoint
      configuration[:endpoint] || 'localhost'
    end

    def required_api_key_parts
      ['search-XXXX']
    end

    private # ----------------------------------------------------------------

    def base_query_url(query)
      query_type = query.reverse_geocode? ? 'reverse' : 'search'
      "#{protocol}://#{endpoint}/v1/#{query_type}?"
    end

    def query_url_params(query)
      params = {
        apikey: configuration.api_key
      }.merge(super)

      if query.reverse_geocode?
        lat, lon = query.coordinates
        params[:'point.lat'] = lat
        params[:'point.lon'] = lon
      else
        params[:text] = query.text
      end
      params
    end

    def results(query)
      return [] unless doc = fetch_data(query)

      # not all responses include a meta
      if doc['meta']
        error = doc.fetch('results', {}).fetch('error', {})
        message = error.fetch('type', 'Unknown Error') + ': ' + error.fetch('message', 'No message')
        log_message = 'Pelias Zip Geocoding API error - ' + message
        case doc['meta']['status_code']
          when '200'
            # nothing to see here
          when '403'
            raise_error(Geocoder::RequestDenied, message) || Geocoder.log(:warn, log_message)
          when '429'
            raise_error(Geocoder::OverQueryLimitError, message) || Geocoder.log(:warn, log_message)
          else
            raise_error(Geocoder::Error, message) || Geocoder.log(:warn, log_message)
        end
      end

      doc['features'] || []
    end
  end
end

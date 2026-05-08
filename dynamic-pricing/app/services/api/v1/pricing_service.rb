module Api::V1
  class PricingService < BaseService
    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      cache_key = "rate_#{@period}_#{@hotel}_#{@room}"
      @result = cache.read(cache_key)
      return if @result.present?

      response = RateApiClient.get_rate(period: @period, hotel: @hotel, room: @room)
      if response.success?
        parsed_response = JSON.parse(response.body)
        rates = parsed_response['rates']

        unless rates.is_a?(Array)
          logger.error "Unexpected Rate API response format: missing or invalid rates"
          errors << "Rate not found. Please try again later."
          return
        end

        @result = rates.detect { |r| r['period'] == @period && r['hotel'] == @hotel && r['room'] == @room }&.dig('rate')

        if @result.present?
          cache.write(cache_key, @result, expires_in: 5.minute)
        else
          # Confirm why API returns a missing rate to determine expected behavior
          # For now, return generic error
          logger.warn "Rate not found for period: #{@period}, hotel: #{@hotel}, room: #{@room}"
          errors << "Rate not found. Please try again later."
          return
        end
      else
        logger.error "Error in RateApiClient.get_rate: #{response.body}"
        errors << "Rate not found. Please try again later."
        return
      end
    end
  end
end

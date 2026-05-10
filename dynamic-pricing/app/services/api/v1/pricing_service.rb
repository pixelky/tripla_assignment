module Api::V1
  class PricingService < BaseService
    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      cache_key = "rate/#{@period}_#{@hotel}_#{@room}"
      # @result = cache.read(cache_key)
      return if @result.present?

      pricing_response = RateApiClient.get_rate(period: @period, hotel: @hotel, room: @room)
      matching_rate = pricing_response.find_rate(period: @period, hotel: @hotel, room: @room)

      @result = matching_rate&.rate

      if @result.present?
        cache.write(cache_key, @result, expires_in: 5.minute)
      else
        # Confirm why API returns a missing rate to determine expected behavior
        # For now, return generic error
        fail_with_default_error("Rate not found for period: #{@period}, hotel: #{@hotel}, room: #{@room}")
        return
      end
    rescue ExternalApiClientException => e
      fail_with_default_error("External API request failed: #{e.message}")
    end

    private

    def fail_with_default_error(log_message)
      logger.error(log_message)
      errors << "Rate not found. Please try again later."
    end
  end
end

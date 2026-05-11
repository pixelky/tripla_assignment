module Api::V1
  class PricingService < BaseService
    CACHE_TTL = 5.minutes

    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      cache_key = cache_key_for(period: @period, hotel: @hotel, room: @room)
      @result = cache.read(cache_key)
      return if @result.present?

      # If rate not in cache, fetch all rates and write to cache
      pricing_response = RateApiClient.get_all_rates
      write_rates_to_cache(pricing_response.rates)

      @result = cache.read(cache_key)

      unless @result.present?
        fail_with_default_error("Rate not found for period: #{@period}, hotel: #{@hotel}, room: #{@room}")
        return
      end
    rescue ExternalApiClientException => e
      fail_with_default_error("External API request failed: #{e.message}")
    end

    private

    def write_rates_to_cache(rates)
      rates.each do |rate|
        next unless rate.rate.present?

        cache.write(
          cache_key_for(period: rate.period, hotel: rate.hotel, room: rate.room),
          rate.rate,
          expires_in: CACHE_TTL
        )
      end
    end

    def cache_key_for(period:, hotel:, room:)
      "rate/#{period}_#{hotel}_#{room}"
    end

    def fail_with_default_error(log_message)
      logger.error(log_message)
      errors << "Rate not found. Please try again later."
    end
  end
end

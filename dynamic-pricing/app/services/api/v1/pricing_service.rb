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
      cache_result = safe_cache_read(cache_key)

      # If cache is down, just return an error
      unless cache_result[:success]
        fail_with_default_error
        return
      end

      # If rate is found in cache, return it. Else fetch from pricing model and write to cache
      @result = cache_result[:value]
      return if @result.present?

      pricing_response = RateApiClient.get_all_rates
      write_rates_to_cache(pricing_response.rates)

      requested_rate = pricing_response.find_rate(period: @period, hotel: @hotel, room: @room)
      @result = requested_rate&.rate

      unless @result.present?
        fail_with_default_error("Rate not found for period: #{@period}, hotel: #{@hotel}, room: #{@room}")
        return
      end
    rescue ExternalApiClientException => e
      fail_with_default_error("External API request failed: #{e.message}")
      return
    end

    private

    def write_rates_to_cache(rates)
      rates.each do |rate|
        next unless rate.rate.present?

        safe_cache_write(
          cache_key_for(period: rate.period, hotel: rate.hotel, room: rate.room),
          rate.rate,
          expires_in:CACHE_TTL
        )
      end
    end

    # Safe read in case cache is down
    def safe_cache_read(cache_key)
      {
        success: true,
        value: cache.read(cache_key)
      }
    rescue => e
      logger.error("Cache read failed for #{cache_key}: #{e.class} - #{e.message}")

      {
        success: false,
        value: nil
      }
    end

    # Safe write in case cache is down
    def safe_cache_write(cache_key, value, expires_in:)
      cache.write(cache_key, value, expires_in:)
    rescue => e
      logger.error("Cache write failed for #{cache_key}: #{e.class} - #{e.message}")
      false
    end

    def cache_key_for(period:, hotel:, room:)
      "rate/#{period}_#{hotel}_#{room}"
    end

    def fail_with_default_error(log_message = nil)
      logger.error(log_message) if log_message.present?
      errors << "Rate not found. Please try again later."
    end
  end
end

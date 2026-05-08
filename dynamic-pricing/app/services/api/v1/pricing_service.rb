module Api::V1
  class PricingService < BaseService
    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      cache_key = "rate_#{@period}_#{@hotel}_#{@room}"
      @result = Rails.cache.read(cache_key)
      return if @result.present?

      response = RateApiClient.get_rate(period: @period, hotel: @hotel, room: @room)
      if response.success?
        parsed_response = JSON.parse(response.body)
        @result = parsed_response['rates'].detect { |r| r['period'] == @period && r['hotel'] == @hotel && r['room'] == @room }&.dig('rate')
        Rails.cache.write(cache_key, @result, expires_in: 5.minute)
      else
        errors << response.body['error']
      end
    end
  end
end

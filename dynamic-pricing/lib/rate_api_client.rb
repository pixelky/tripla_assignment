require_relative "http_client_with_retries"

class RateApiClient
  include HTTParty
  extend HttpClientWithRetries

  VALID_PERIODS = %w[Summer Autumn Winter Spring].freeze
  VALID_HOTELS = %w[FloatingPointResort GitawayHotel RecursionRetreat].freeze
  VALID_ROOMS = %w[SingletonRoom BooleanTwin RestfulKing].freeze

  base_uri ENV.fetch('RATE_API_URL', 'http://localhost:8080')
  headers "Content-Type" => "application/json"
  headers 'token' => ENV.fetch('RATE_API_TOKEN', '04aa6f42aa03f220c2ae9a276cd68c62')

  def self.get_rate(period:, hotel:, room:)
    params = {
      attributes: [
        {
          period: period,
          hotel: hotel,
          room: room
        }
      ]
    }.to_json

    response = post_with_retries(
      "/pricing",
      { body: params }
    )

    handle_error_response(response) unless response.success?

    GetRateResponse.from_hash(JSON.parse(response.body))
  rescue => e
    Rails.logger.error("RateApiClient.get_rate failed: #{e.class} - #{e.message}")
    raise ExternalApiClientException, "Rate API request failed"
  end

  # Fetch rates for all possible combinations
  def self.get_all_rates
    params = {
      attributes: VALID_PERIODS.product(VALID_HOTELS, VALID_ROOMS).map do |period, hotel, room|
        {
          period: period,
          hotel: hotel,
          room: room
        }
      end
    }.to_json

    response = post_with_retries(
      "/pricing",
      { body: params }
    )

    handle_error_response(response) unless response.success?

    GetRateResponse.from_hash(JSON.parse(response.body))
  rescue => e
    Rails.logger.error("RateApiClient.get_all_rates failed: #{e.class} - #{e.message}")
    raise ExternalApiClientException, "Rate API request failed"
  end

  def self.handle_error_response(response)
    Rails.logger.error("RateApiClient request failed: #{response.code}: #{response.body}")
    raise ExternalApiClientException, "Rate API request failed"
  end

  private_class_method :handle_error_response
end

# Improvement: Move below classes to another directory
class Rate
  attr_reader :period, :hotel, :room, :rate

  def self.from_hash(payload)
    new(
      period: payload["period"],
      hotel: payload["hotel"],
      room: payload["room"],
      rate: payload["rate"]
    )
  end

  def initialize(period:, hotel:, room:, rate:)
    @period = period
    @hotel = hotel
    @room = room
    @rate = rate
  end

  def matches?(period:, hotel:, room:)
    @period == period &&
      @hotel == hotel &&
      @room == room
  end
end

class GetRateResponse
  attr_reader :rates

  def self.from_hash(payload)
    rates = payload["rates"]

    unless rates.is_a?(Array)
      raise ExternalApiClientException, "Rate API response missing or invalid rates"
    end

    new(rates: rates.map { |rate| Rate.from_hash(rate) })
  end

  def initialize(rates:)
    @rates = rates
  end

  def find_rate(period:, hotel:, room:)
    rates.find { |rate| rate.matches?(period:, hotel:, room:) }
  end
end
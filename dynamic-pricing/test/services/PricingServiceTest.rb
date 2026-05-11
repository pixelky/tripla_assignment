require "test_helper"
require Rails.root.join("lib/rate_api_client")

module Api::V1
  class PricingServiceTest < ActiveSupport::TestCase
    REQUESTED_CACHE_KEY = "rate/Summer_FloatingPointResort_SingletonRoom"

    setup do
      Rails.cache.clear
    end

    test "returns cached rate without calling rate api client" do
      Rails.cache.write(REQUESTED_CACHE_KEY, "15000", expires_in: 5.minutes)

      get_all_rates = -> { raise "RateApiClient.get_all_rates should not be called on cache hit" }

      RateApiClient.stub(:get_all_rates, get_all_rates) do
        service = PricingService.new(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )

        service.run

        assert service.valid?
        assert_equal "15000", service.result
      end
    end

    test "fetches all rates on cache miss and returns requested rate" do
      pricing_response = GetRateResponse.from_hash({
        "rates" => [
          {
            "period" => "Summer",
            "hotel" => "FloatingPointResort",
            "room" => "SingletonRoom",
            "rate" => "15000"
          },
          {
            "period" => "Winter",
            "hotel" => "GitawayHotel",
            "room" => "BooleanTwin",
            "rate" => "12000"
          }
        ]
      })

      RateApiClient.stub(:get_all_rates, pricing_response) do
        service = PricingService.new(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )

        service.run

        assert service.valid?
        assert_equal "15000", service.result
      end
    end

    test "writes all returned rates with present rate values to cache" do
      pricing_response = GetRateResponse.from_hash({
        "rates" => [
          {
            "period" => "Summer",
            "hotel" => "FloatingPointResort",
            "room" => "SingletonRoom",
            "rate" => "15000"
          },
          {
            "period" => "Winter",
            "hotel" => "GitawayHotel",
            "room" => "BooleanTwin",
            "rate" => "12000"
          }
        ]
      })

      RateApiClient.stub(:get_all_rates, pricing_response) do
        service = PricingService.new(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )

        service.run

        assert_equal "15000", Rails.cache.read("rate/Summer_FloatingPointResort_SingletonRoom")
        assert_equal "12000", Rails.cache.read("rate/Winter_GitawayHotel_BooleanTwin")
      end
    end

    test "does not cache returned rates with missing rate value" do
      pricing_response = GetRateResponse.from_hash({
        "rates" => [
          {
            "period" => "Summer",
            "hotel" => "FloatingPointResort",
            "room" => "SingletonRoom"
          },
          {
            "period" => "Winter",
            "hotel" => "GitawayHotel",
            "room" => "BooleanTwin",
            "rate" => "12000"
          }
        ]
      })

      RateApiClient.stub(:get_all_rates, pricing_response) do
        service = PricingService.new(
          period: "Winter",
          hotel: "GitawayHotel",
          room: "BooleanTwin"
        )

        service.run

        assert_nil Rails.cache.read("rate/Summer_FloatingPointResort_SingletonRoom")
        assert_equal "12000", Rails.cache.read("rate/Winter_GitawayHotel_BooleanTwin")
      end
    end

    test "returns error when requested rate is not found after cache warm" do
      pricing_response = GetRateResponse.from_hash({
        "rates" => [
          {
            "period" => "Winter",
            "hotel" => "GitawayHotel",
            "room" => "BooleanTwin",
            "rate" => "12000"
          }
        ]
      })

      RateApiClient.stub(:get_all_rates, pricing_response) do
        service = PricingService.new(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )

        service.run

        refute service.valid?
        assert_nil service.result
        assert_includes service.errors, "Rate not found. Please try again later."
      end
    end

    test "returns error when requested rate exists but rate value is missing" do
      pricing_response = GetRateResponse.from_hash({
        "rates" => [
          {
            "period" => "Summer",
            "hotel" => "FloatingPointResort",
            "room" => "SingletonRoom"
          }
        ]
      })

      RateApiClient.stub(:get_all_rates, pricing_response) do
        service = PricingService.new(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )

        service.run

        refute service.valid?
        assert_nil service.result
        assert_includes service.errors, "Rate not found. Please try again later."
        assert_nil Rails.cache.read(REQUESTED_CACHE_KEY)
      end
    end

    test "returns error when rate api client raises exception" do
      get_all_rates = -> { raise ExternalApiClientException, "Rate API request failed" }

      RateApiClient.stub(:get_all_rates, get_all_rates) do
        service = PricingService.new(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )

        service.run

        refute service.valid?
        assert_nil service.result
        assert_includes service.errors, "Rate not found. Please try again later."
      end
    end
  end
end

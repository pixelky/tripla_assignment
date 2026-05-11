require "test_helper"
require Rails.root.join("lib/rate_api_client")

class RateApiClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:success?, :code, :body, keyword_init: true)

  test "get_rate returns GetRateResponse for successful response" do
    response = FakeResponse.new(
      success?: true,
      code: 200,
      body: {
        "rates" => [
          {
            "period" => "Summer",
            "hotel" => "FloatingPointResort",
            "room" => "SingletonRoom",
            "rate" => "15000"
          }
        ]
      }.to_json
    )

    RateApiClient.stub(:post_with_retries, response) do
      result = RateApiClient.get_rate(
        period: "Summer",
        hotel: "FloatingPointResort",
        room: "SingletonRoom"
      )

      assert_instance_of GetRateResponse, result
      assert_equal 1, result.rates.size

      rate = result.rates.first
      assert_instance_of Rate, rate
      assert_equal "Summer", rate.period
      assert_equal "FloatingPointResort", rate.hotel
      assert_equal "SingletonRoom", rate.room
      assert_equal "15000", rate.rate
    end
  end

  test "get_rate allows rate field to be missing" do
    response = FakeResponse.new(
      success?: true,
      code: 200,
      body: {
        "rates" => [
          {
            "period" => "Summer",
            "hotel" => "FloatingPointResort",
            "room" => "SingletonRoom"
          }
        ]
      }.to_json
    )

    RateApiClient.stub(:post_with_retries, response) do
      result = RateApiClient.get_rate(
        period: "Summer",
        hotel: "FloatingPointResort",
        room: "SingletonRoom"
      )

      rate = result.rates.first

      assert_equal "Summer", rate.period
      assert_equal "FloatingPointResort", rate.hotel
      assert_equal "SingletonRoom", rate.room
      assert_nil rate.rate
    end
  end

  test "get_rate raises ExternalApiClientException for non-success response" do
    response = FakeResponse.new(
      success?: false,
      code: 500,
      body: { "error" => "server error" }.to_json
    )

    RateApiClient.stub(:post_with_retries, response) do
      assert_raises ExternalApiClientException do
        RateApiClient.get_rate(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )
      end
    end
  end

  test "get_rate raises ExternalApiClientException for invalid JSON response" do
    response = FakeResponse.new(
      success?: true,
      code: 200,
      body: "not-json"
    )

    RateApiClient.stub(:post_with_retries, response) do
      assert_raises ExternalApiClientException do
        RateApiClient.get_rate(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )
      end
    end
  end

  test "get_rate raises ExternalApiClientException when rates are missing" do
    response = FakeResponse.new(
      success?: true,
      code: 200,
      body: {}.to_json
    )

    RateApiClient.stub(:post_with_retries, response) do
      assert_raises ExternalApiClientException do
        RateApiClient.get_rate(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )
      end
    end
  end

  test "get_rate raises ExternalApiClientException when rates is not an array" do
    response = FakeResponse.new(
      success?: true,
      code: 200,
      body: { "rates" => {} }.to_json
    )

    RateApiClient.stub(:post_with_retries, response) do
      assert_raises ExternalApiClientException do
        RateApiClient.get_rate(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )
      end
    end
  end

  test "get_rate wraps post_with_retries exception as ExternalApiClientException" do
    RateApiClient.stub(:post_with_retries, ->(*) { raise Net::ReadTimeout }) do
      assert_raises ExternalApiClientException do
        RateApiClient.get_rate(
          period: "Summer",
          hotel: "FloatingPointResort",
          room: "SingletonRoom"
        )
      end
    end
  end

  test "GetRateResponse finds matching rate" do
    response = GetRateResponse.from_hash({
      "rates" => [
        {
          "period" => "Winter",
          "hotel" => "GitawayHotel",
          "room" => "BooleanTwin",
          "rate" => "12000"
        },
        {
          "period" => "Summer",
          "hotel" => "FloatingPointResort",
          "room" => "SingletonRoom",
          "rate" => "15000"
        }
      ]
    })

    rate = response.find_rate(
      period: "Summer",
      hotel: "FloatingPointResort",
      room: "SingletonRoom"
    )

    assert_equal "15000", rate.rate
  end

  test "GetRateResponse returns nil when no rate matches" do
    response = GetRateResponse.from_hash({
      "rates" => [
        {
          "period" => "Winter",
          "hotel" => "GitawayHotel",
          "room" => "BooleanTwin",
          "rate" => "12000"
        }
      ]
    })

    rate = response.find_rate(
      period: "Summer",
      hotel: "FloatingPointResort",
      room: "SingletonRoom"
    )

    assert_nil rate
  end

  test "get_all_rates posts all possible pricing combinations" do
    response = FakeResponse.new(
      success?: true,
      code: 200,
      body: {
        "rates" => [
          {
            "period" => "Summer",
            "hotel" => "FloatingPointResort",
            "room" => "SingletonRoom",
            "rate" => "15000"
          }
        ]
      }.to_json
    )

    captured_path = nil
    captured_options = nil

    RateApiClient.stub(:post_with_retries, ->(path, options) {
      captured_path = path
      captured_options = options
      response
    }) do
      RateApiClient.get_all_rates
    end

    assert_equal "/pricing", captured_path

    body = JSON.parse(captured_options[:body])
    attributes = body["attributes"]

    assert_equal 36, attributes.size
  end

  test "get_all_rates returns GetRateResponse for successful response" do
    response = FakeResponse.new(
      success?: true,
      code: 200,
      body: {
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
      }.to_json
    )

    RateApiClient.stub(:post_with_retries, response) do
      result = RateApiClient.get_all_rates

      assert_instance_of GetRateResponse, result
      assert_equal 2, result.rates.size

      first_rate = result.find_rate(
        period: "Summer",
        hotel: "FloatingPointResort",
        room: "SingletonRoom"
      )

      second_rate = result.find_rate(
        period: "Winter",
        hotel: "GitawayHotel",
        room: "BooleanTwin"
      )

      assert_equal "15000", first_rate.rate
      assert_equal "12000", second_rate.rate
    end
  end

  test "get_all_rates raises ExternalApiClientException for non-success response" do
    response = FakeResponse.new(
      success?: false,
      code: 500,
      body: { "error" => "server error" }.to_json
    )

    RateApiClient.stub(:post_with_retries, response) do
      assert_raises ExternalApiClientException do
        RateApiClient.get_all_rates
      end
    end
  end

  test "get_all_rates raises ExternalApiClientException for invalid JSON response" do
    response = FakeResponse.new(
      success?: true,
      code: 200,
      body: "not-json"
    )

    RateApiClient.stub(:post_with_retries, response) do
      assert_raises ExternalApiClientException do
        RateApiClient.get_all_rates
      end
    end
  end

  test "get_all_rates wraps post_with_retries exception as ExternalApiClientException" do
    RateApiClient.stub(:post_with_retries, ->(*) { raise Net::ReadTimeout }) do
      assert_raises ExternalApiClientException do
        RateApiClient.get_all_rates
      end
    end
  end
end

require "test_helper"
require Rails.root.join("lib/http_client_with_retries")

class HttpClientWithRetriesTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code)

  class FakeClient
    include HttpClientWithRetries

    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def post(path, options)
      @requests << { path: path, options: options }

      response = @responses.shift
      raise response if response.is_a?(Exception)

      response
    end
  end

  test "returns response immediately when response is successful" do
    success_response = FakeResponse.new(200)
    client = FakeClient.new([success_response])

    response = client.post_with_retries(
      "/pricing",
      { body: "{}" },
      max_retries: 2,
      retry_delay: 0
    )

    assert_equal success_response, response
    assert_equal 1, client.requests.size
  end

  test "retries retryable response and returns successful response" do
    retryable_response = FakeResponse.new(500)
    success_response = FakeResponse.new(200)
    client = FakeClient.new([retryable_response, success_response])

    response = client.post_with_retries(
      "/pricing",
      { body: "{}" },
      max_retries: 1,
      retry_delay: 0
    )

    assert_equal success_response, response
    assert_equal 2, client.requests.size
  end

  test "returns latest response when retryable response keeps failing" do
    failed_response_1 = FakeResponse.new(500)
    failed_response_2 = FakeResponse.new(500)
    client = FakeClient.new([
      failed_response_1,
      failed_response_2
    ])

    response = client.post_with_retries(
      "/pricing",
      { body: "{}" },
      max_retries: 1,
      retry_delay: 0
    )

    assert_equal failed_response_2, response
    assert_equal 2, client.requests.size
  end

  test "does not retry non-retryable error response" do
    bad_request_response = FakeResponse.new(400)
    client = FakeClient.new([bad_request_response])

    response = client.post_with_retries(
      "/pricing",
      { body: "{}" },
      max_retries: 2,
      retry_delay: 0
    )

    assert_equal bad_request_response, response
    assert_equal 1, client.requests.size
  end

  test "retries retryable exception and returns successful response" do
    success_response = FakeResponse.new(200)
    client = FakeClient.new([
      Net::ReadTimeout.new,
      success_response
    ])

    response = client.post_with_retries(
      "/pricing",
      { body: "{}" },
      max_retries: 1,
      retry_delay: 0
    )

    assert_equal success_response, response
    assert_equal 2, client.requests.size
  end

  test "re-raises original retryable exception when retries are exhausted" do
    client = FakeClient.new([
      Net::OpenTimeout.new,
      Net::ReadTimeout.new
    ])

    assert_raises Net::ReadTimeout do
      client.post_with_retries(
        "/pricing",
        { body: "{}" },
        max_retries: 1,
        retry_delay: 0
      )
    end

    assert_equal 2, client.requests.size
  end

  test "does not rescue non-retryable exceptions" do
    client = FakeClient.new([
      ArgumentError.new("unexpected error")
    ])

    assert_raises ArgumentError do
      client.post_with_retries(
        "/pricing",
        { body: "{}" },
        max_retries: 1,
        retry_delay: 0
      )
    end

    assert_equal 1, client.requests.size
  end
end

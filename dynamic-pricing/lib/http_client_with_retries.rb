module HttpClientWithRetries
  DEFAULT_RETRYABLE_STATUS_CODES = [500, 502, 503, 504].freeze
  DEFAULT_RETRYABLE_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    SocketError
  ].freeze
  DEFAULT_OPEN_TIMEOUT_SECONDS = 0.25
  DEFAULT_READ_TIMEOUT_SECONDS = 1.5
  DEFAULT_MAX_RETRIES = 2
  DEFAULT_RETRY_DELAY = 0.5

  def post_with_retries(
    path,
    options,
    open_timeout: DEFAULT_OPEN_TIMEOUT_SECONDS,
    read_timeout: DEFAULT_READ_TIMEOUT_SECONDS,
    max_retries: DEFAULT_MAX_RETRIES,
    retry_delay: DEFAULT_RETRY_DELAY,
    retryable_status_codes: DEFAULT_RETRYABLE_STATUS_CODES,
    retryable_errors: DEFAULT_RETRYABLE_ERRORS
  )
    attempts = 0

    loop do
      response = post(
        path,
        options.merge(
          open_timeout: open_timeout,
          read_timeout: read_timeout
        )
      )

      return response unless retryable_status_codes.include?(response.code)

      attempts += 1

      # Return final attempt response as-is
      if attempts > max_retries
        return response
      end

      sleep retry_delay
    rescue *retryable_errors => e
      attempts += 1

      raise if attempts > max_retries

      sleep retry_delay
    end
  end
end

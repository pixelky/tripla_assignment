# Submission
This document outlines my submission for the Dynamic Pricing Assignment.
It includes my approach to the main challenge, a list of the changes made, possible improvements, and a few real-life considerations beyond the scope fo the assignment.
It was an interesting assignment and I look forward to having our discussion.

## Main Challenge
The main challenge of this assignment seems to be the 1,000 calls per day rate limit on the `/pricing` endpoint of the pricing model API.
Taking this as an unavoidable constraint, we need to figure out how to ensure that the intermediary service operates within the pricing model's rate limit.

As mentioned in the core requirements in the README, any rate fetched from the pricing model API is only valid for 5 minutes.
Furthermore, the intermediary service is expected to handle at least 10,000 requests per day, while using a single API token.
There are a total of 36 (4 periods * 3 hotels * 3 rooms) possible combinations of parameters, and there are 288 five-minute windows in a day.
In the worst case, if all 36 combinations are queried every 5 minutes, the service would need to make 36 * 288 = 10,224 API calls per day, which exceeds the 1,000 call limit.
Therefore, it seems necessary to reduce the number of API calls by fetching multiple rates at once.
Permutating at least two parameters (period + room/hotel) at a time may work, but brings us near the rate limit (288 * 3 = 816 calls).
Within the scope of this assignment, although making a call for all combinations is expensive, it seems sensible to fetch all rates at once on each API call and cache them, which is the approach I chose for this assignment.

In regard to caching, I decided to return an error immediately if the cache is down, instead of fetching directly from the pricing model.
An alternative would be to fetch directly from the pricing model during the cache downtime, but we may easily exceed the 1,000 call rate limit of the pricing model API.
In a real-life scenario, we can ensure that the cache service is deployed with high availability to minimize any issues.

## Changes Made

### Summary
- Implemented redis caching for rates. (Added redis to docker-compose)
- Fetch all rates instead of just the requested rate to warm cache.
- Implemented HTTP retries for the API call to the pricing model to handle intermittent issues.
- Improved error handling and added logging.
- Added a DTO (GetRateResponse) to encapsulate the API response.
- Added tests.

### Fetching from the Pricing Model & Caching (Main Challenge)
- Fetch all rates at once on each pricing model API call instead of just a single rate.
- Implemented caching where the rates are cached for 5 minutes in Redis.
- If the cache is down, the service returns an error immediately.
- Regarding choice of cache:
  - The main reason for choosing Redis is that it is a distributed cache that can be accessed by multiple server instances, as opposed to an in-memory cache.
  - For a system that operates at a Tripla's scale, there will definitely be multiple instances of this service for availability and scalability.
  - Redis can also be reused for other caching needs.
  - In production, Redis should be deployed with redundancy in mind, using sentinel/cluster setup.

### Error Handling and Logging

#### HTTP Retries
- Implemented a simple, reusable post_with_retry function to handle HTTP retries.
- The API call seems to sometimes timeout, which in this assignment seems solvable with retries.
- In a real system, retries should be used on a case-by-case basis if it makes sense.

#### Pricing Model Response Issues
- The error handling for HTTP client and response issues is implemented in the RateApiClient.
- Any issues are logged, and an ExternalApiClientException is raised.
- Sometimes the response is missing the 'rate' field. This is considered a valid response and is handled accordingly in the service.

### DTO
- A DTO (GetRateResponse) has been implemented, which is returned by get_rate.
- This moves the parsing of the API response to RateApiClient instead of handling it in the service.
- The DTO encapsulates the response data and provides a clear interface for accessing the rate information.
- This improves code readability and maintainability by separating concerns and providing a clear contract for the response data.
- The DTO also allows for easy extension and modification of the response data structure without affecting the service logic.

### Testing
- Implemented unit tests for PricingService, RateApiClient, and post_with_retry function.
- Updated PricingController tests.

## Possible Improvements
- Follow parse, don't validate (e.g. for the request body).
- Create more DTOs and types (Domain Driven Design).
- Improve the directory structure to better organize the project.
- Use in-memory cache as a backup (but could cause problems with hitting the rate limit).
- Improve retry behavior with exponential backoff and jitter.
- More descriptive error messages as needed.

## Real-life Considerations
- There will not be a fixed number of combinations of parameters, so we need a more complicated querying strategy backed by analytics.
- We could run the pricing model and cache periodically instead of on-demand.
- Figure out why the pricing model sometimes times out or returns missing rates and address those issues within the pricing model.

## AI Usage
- I used RubyMine's built-in AI assistant.
- As I am completely unfamiliar with Ruby, AI was used to write the bulk of the code in the submission, while I provided the logic.
- Tests were also written using AI, and I reviewed the test cases.

## Running the Service
- Please refer to the Quickstart Guide in the original README.
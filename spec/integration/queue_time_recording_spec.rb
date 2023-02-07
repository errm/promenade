require "rails_helper"
require "support/queue_time_header_helpers"

RSpec.describe "Queue time recording", type: :request, time_helpers: true do
  include QueueTimeHeaderHelpers

  ##
  # This value is greater than the first bucket, but smaller than the second.
  # This allows us to test that time series are being set properly.
  let(:expected_queue_time) { 0.04 }

  let(:expected_labels) do
    {
      code: "200",
      controller_action: "test_responses#success",
      host: "www.example.com",
      method: "get",
    }
  end

  let(:histogram) do
    ::Prometheus::Client.registry.get(:http_req_queue_time_seconds)
  end

  context "when X-Request-start header is present" do
    it "records the queue time" do
      freeze_time

      start_time = Time.now.utc - expected_queue_time

      get "/success", headers: { "x-request-start" => request_start_timestamp(start_time) }

      expect(histogram).to have_time_series_value(1.0).
        for_buckets_greater_than_or_equal_to(expected_queue_time).
        with_labels(expected_labels)
      expect(histogram).to have_time_series_value(0.0).
        for_buckets_less_than(expected_queue_time).
        with_labels(expected_labels)
    end
  end

  context "when X-Queue-start header is present" do
    it "records the queue time" do
      freeze_time
      start_time = Time.now.utc - expected_queue_time

      get "/success", headers: { "x-queue-start" => request_start_timestamp(start_time) }

      expect(histogram).to have_time_series_value(1.0).
        for_buckets_greater_than_or_equal_to(expected_queue_time).
        with_labels(expected_labels)
      expect(histogram).to have_time_series_value(0.0).
        for_buckets_less_than(expected_queue_time).
        with_labels(expected_labels)
    end
  end

  context "when no header is present" do
    it "doesn't record any data" do
      freeze_time

      get "/success", headers: {}

      expect(histogram.values).to be_empty
    end
  end

  context "when header value isn't a valid timestamp" do
    it "doesn't record any data" do
      freeze_time
      start_time = Time.now.utc - expected_queue_time

      get "/success", headers: { "x-request-start" => start_time.to_s }

      expect(histogram.values).to be_empty
    end
  end
end

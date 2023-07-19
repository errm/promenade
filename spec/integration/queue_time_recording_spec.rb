require "rails_helper"
require "active_support/testing/time_helpers"
require "active_support/core_ext/numeric/time"
require "active_support/duration"

require "support/queue_time_header_helpers"

RSpec.describe "Queue time recording", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  include QueueTimeHeaderHelpers

  it "records the queue time if X-Request-start header is present" do
    freeze_time
    start_time = Time.now.utc - 0.01

    histogram = Prometheus::Client.registry.get(:http_request_queue_time_seconds)
    expected_queue_time = 0.01
    expected_labels = {
      code: "200",
      host: "www.example.com",
      method: "get",
    }

    expect(histogram).to receive(:observe).with(expected_labels, expected_queue_time)

    get "/success", headers: { "x-request-start" => request_start_timestamp(start_time) }
  end

  it "records the queue time if X-Queue-start header is present" do
    freeze_time
    start_time = Time.now.utc - 0.01

    histogram = Prometheus::Client.registry.get(:http_request_queue_time_seconds)
    expected_queue_time = 0.01
    expected_labels = {
      code: "200",
      host: "www.example.com",
      method: "get",
    }

    expect(histogram).to receive(:observe).with(expected_labels, expected_queue_time)

    get "/success", headers: { "x-queue-start" => request_start_timestamp(start_time) }
  end

  it "doesn't attempt to record if no header is present" do
    freeze_time
    histogram = Prometheus::Client.registry.get(:http_request_queue_time_seconds)

    expect(histogram).not_to receive(:observe)

    get "/success", headers: {}
  end

  it "doesn't attempt to record if header is not valid format" do
    freeze_time
    start_time = Time.now.utc - 0.01
    histogram = Prometheus::Client.registry.get(:http_request_queue_time_seconds)

    expect(histogram).to_not receive(:observe)

    get "/success", headers: { "x-request-start" => start_time.to_s }
  end
end

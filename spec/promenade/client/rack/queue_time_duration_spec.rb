require "spec_helper"
require "promenade/client/rack/queue_time_duration"
require "active_support/testing/time_helpers"
require "support/queue_time_header_helpers"

RSpec.describe Promenade::Client::Rack::QueueTimeDuration do
  include ActiveSupport::Testing::TimeHelpers
  include QueueTimeHeaderHelpers


  describe "#queue_time_seconds" do
    before do
      freeze_time
    end

    it "returns nil when no queue header present" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(env: {})
      expect(duration.queue_time_seconds).to be_nil
    end

    it "returns nil when queue header is Timestamp format" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => Time.now.utc.to_s },
      )

      expect(duration.queue_time_seconds).to be_nil
    end

    it "returns nil when queue header is an invalid Integer" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => 1234 },
      )

      expect(duration.queue_time_seconds).to be_nil
    end

    it "returns the correct value when queue header is present and a valid value" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: {
          "HTTP_X_QUEUE_START" => request_start_timestamp(Time.now.utc - 2),
        },
      )
      expect(duration.queue_time_seconds).to eql(2.0)
    end

    it "prioritises HTTP_X_REQUEST_START before HTTP_X_QUEUE_START" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: {
          "HTTP_X_REQUEST_START" => request_start_timestamp(Time.now.utc - 10),
          "HTTP_X_QUEUE_START" => request_start_timestamp(Time.now.utc - 5),
        }
      )

      expect(duration.queue_time_seconds).to eql(10.0)

      # Perform same expectation as above, but with the values flipped. This way
      # we can ensure we're testing the priority of the headers
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: {
          "HTTP_X_QUEUE_START" => request_start_timestamp(Time.now.utc - 10),
          "HTTP_X_REQUEST_START" => request_start_timestamp(Time.now.utc - 5),
        }
      )

      expect(duration.queue_time_seconds).to eql(5.0)
    end

    it "returns nil when the header is present but has no 't=' prefix" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => Time.now.to_f.to_s },
      )

      expect(duration.queue_time_seconds).to be_nil
    end

    it "returns nil when the header is present but has invalid timestamp" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => "invalid-value" },
      )

      expect(duration.queue_time_seconds).to be_nil
    end

    it "returns the difference between queue time and received time when valid" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => request_start_timestamp(Time.now.utc - 10) },
      )

      expect(duration.queue_time_seconds).to eq(10.0)
    end

    it "returns nil if the request was enqueued after the request was received" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => request_start_timestamp(Time.now.utc + 10) },
      )

      expect(duration.queue_time_seconds).to be_nil
    end
  end
end

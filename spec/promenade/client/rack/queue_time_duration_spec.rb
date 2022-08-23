require "spec_helper"
require "promenade/client/rack/queue_time_duration"
require "active_support/testing/time_helpers"
require "support/queue_time_header_helpers"

RSpec.describe Promenade::Client::Rack::QueueTimeDuration do
  include ActiveSupport::Testing::TimeHelpers
  include QueueTimeHeaderHelpers

  describe "#valid_header_present?" do
    it "returns false when no queue header present" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: {},
        request_received_time: Time.now.utc,
      )

      expect(duration.valid_header_present?).to be(false)
    end

    it "returns false when queue header is Timestamp format" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => Time.now.utc.to_s },
        request_received_time: Time.now.utc,
      )

      expect(duration.valid_header_present?).to be(false)
    end

    it "returns false when queue header is an invalid Integer" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => 1234 },
        request_received_time: Time.now.utc,
      )

      expect(duration.valid_header_present?).to be(false)
    end

    it "returns true when queue header is present and a valid value" do
      freeze_time
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => request_start_timestamp },
        request_received_time: Time.now.utc,
      )
      travel_to Time.now.utc + 2 do
        expect(duration.valid_header_present?).to be(true)
      end
    end
  end

  describe "#queue_time_seconds" do
    it "prioritises HTTP_X_REQUEST_START before HTTP_X_QUEUE_START" do
      env = {}
      freeze_time
      travel_to(Time.now.utc - 10) { env["HTTP_X_REQUEST_START"] = request_start_timestamp }
      travel_to(Time.now.utc - 5) { env["HTTP_X_QUEUE_START"] = request_start_timestamp }
      travel_to(Time.now.utc)

      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: env,
        request_received_time: Time.now.utc,
      )

      expect(duration.queue_time_seconds).to eql(10.0)

      # Perform same expectation as above, but with the values flipped. This way
      # we can ensure we're testing the priority of the headers
      travel_to(Time.now.utc - 10) { env["HTTP_X_QUEUE_START"] = request_start_timestamp }
      travel_to(Time.now.utc - 5) { env["HTTP_X_REQUEST_START"] = request_start_timestamp }
      travel_to(Time.now.utc)

      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: env,
        request_received_time: Time.now.utc,
      )

      expect(duration.queue_time_seconds).to eql(5.0)
    end

    it "returns nil when neither HTTP_X_REQUEST_START nor HTTP_X_QUEUE_START is present" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: {},
        request_received_time: Time.now.utc,
      )

      expect(duration.queue_time_seconds).to be(nil)
    end

    it "returns nil when the header is present but has no 't=' prefix" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => Time.now.to_f.to_s },
        request_received_time: Time.now.utc,
      )

      expect(duration.queue_time_seconds).to be(nil)
    end

    it "returns nil when the header is present but has invalid timestamp" do
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: { "HTTP_X_REQUEST_START" => "invalid-value" },
        request_received_time: Time.now.utc,
      )

      expect(duration.queue_time_seconds).to be(nil)
    end

    it "returns the difference between queue time and received time when valid" do
      freeze_time
      env = Hash.new

      travel_to(Time.now.utc - 10) { env["HTTP_X_REQUEST_START"] = request_start_timestamp }
      travel_to(Time.now.utc)
      duration = Promenade::Client::Rack::QueueTimeDuration.new(
        env: env,
        request_received_time: Time.now.utc,
      )

      expect(duration.queue_time_seconds).to eq(10.0)
    end
  end
end

require "spec_helper"
require "promenade/client/rack/http_request_queue_time_collector"
require "active_support/testing/time_helpers"
require "rack/mock"
require "support/test_rack_app"
require "support/queue_time_header_helpers"

RSpec.describe Promenade::Client::Rack::HTTPRequestQueueTimeCollector, reset_prometheus_client: true do
  include ActiveSupport::Testing::TimeHelpers
  include QueueTimeHeaderHelpers

  describe "#call" do
    it "preserves the status code" do
      env = Rack::MockRequest.env_for
      app = TestRackApp.new(status: 418)
      middleware = described_class.new(app)
      status, = middleware.call(env)

      expect(status).to eql(418)
    end

    it "preserves the headers" do
      env = Rack::MockRequest.env_for
      app = TestRackApp.new(headers: { "HTTP_FIZZ" => "buzz" })
      middleware = described_class.new(app)
      _, headers, = middleware.call(env)

      expect(headers).to eql("HTTP_FIZZ" => "buzz")
    end

    it "preserves the body" do
      env = Rack::MockRequest.env_for
      app = TestRackApp.new(body: "test-body")
      middleware = described_class.new(app)
      _, _, body = middleware.call(env)

      expect(body).to eql("test-body")
    end

    it "records a histogram for the queue time when X-Request-Start is present" do
      freeze_time
      queued_at = Time.now.utc - 1.0
      env = Rack::MockRequest.env_for("/",
        "HTTP_HOST" => "test.host",
        "HTTP_X_REQUEST_START" => request_start_timestamp(queued_at))
      app = TestRackApp.new
      middleware = described_class.new(app)

      histogram = fetch_metric(:http_request_queue_time_seconds)
      expect(histogram).to receive(:observe)

      middleware.call(env)
    end

    it "records a histogram with host label and measured queue duration" do
      freeze_time
      queued_at = Time.now.utc - 1.0
      env = Rack::MockRequest.env_for("/",
        "HTTP_HOST" => "test.host",
        "HTTP_X_REQUEST_START" => request_start_timestamp(queued_at))
      app = TestRackApp.new
      middleware = described_class.new(app)

      histogram = fetch_metric(:http_request_queue_time_seconds)
      expected_labels = { host: "test.host" }

      expect(histogram).to receive(:observe).with(expected_labels, 1.0)

      middleware.call(env)
    end

    it "records using X-Queue-Start when X-Request-Start is absent" do
      freeze_time
      queued_at = Time.now.utc - 2.0
      env = Rack::MockRequest.env_for("/",
        "HTTP_HOST" => "test.host",
        "HTTP_X_QUEUE_START" => request_start_timestamp(queued_at))
      app = TestRackApp.new
      middleware = described_class.new(app)

      histogram = fetch_metric(:http_request_queue_time_seconds)
      expected_labels = { host: "test.host" }

      expect(histogram).to receive(:observe).with(expected_labels, 2.0)

      middleware.call(env)
    end

    it "does not record when no queue header is present" do
      freeze_time
      env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "test.host")
      app = TestRackApp.new
      middleware = described_class.new(app)

      histogram = fetch_metric(:http_request_queue_time_seconds)
      expect(histogram).not_to receive(:observe)

      middleware.call(env)
    end

    it "does not record when the header value is not a valid t= timestamp" do
      freeze_time
      env = Rack::MockRequest.env_for("/",
        "HTTP_HOST" => "test.host",
        "HTTP_X_REQUEST_START" => Time.now.utc.to_s)
      app = TestRackApp.new
      middleware = described_class.new(app)

      histogram = fetch_metric(:http_request_queue_time_seconds)
      expect(histogram).not_to receive(:observe)

      middleware.call(env)
    end

    it "accepts a custom block for histogram labels" do
      freeze_time
      queued_at = Time.now.utc - 0.5
      env = Rack::MockRequest.env_for("/",
        "fizz" => "buzz",
        "HTTP_X_REQUEST_START" => request_start_timestamp(queued_at))
      app = TestRackApp.new
      custom_label_builder = proc { |_env| { foo: "bar", fizz: _env["fizz"] } }
      middleware = described_class.new(app, label_builder: custom_label_builder)

      histogram = fetch_metric(:http_request_queue_time_seconds)
      expected_labels = { foo: "bar", fizz: "buzz" }

      expect(histogram).to receive(:observe).with(expected_labels, 0.5)

      middleware.call(env)
    end

    it "accepts a custom set of queue time histogram buckets" do
      Promenade.configure do |config|
        config.queue_time_buckets = [0.1, 0.5, 1.0]
      end

      freeze_time
      queued_at = Time.now.utc - 0.5
      env = Rack::MockRequest.env_for("/",
        "HTTP_HOST" => "test.host",
        "HTTP_X_REQUEST_START" => request_start_timestamp(queued_at))
      app = TestRackApp.new
      middleware = described_class.new(app)
      expected_labels = { host: "test.host" }
      histogram = fetch_metric(:http_request_queue_time_seconds)

      middleware.call(env)

      normalized_histogram_values = histogram_values_to_h(histogram, expected_labels)
      expect(normalized_histogram_values).to eq({ 0.1 => 0.0, 0.5 => 1.0, 1.0 => 1.0 })
    end
  end

  private

    def fetch_metric(metric_name)
      Prometheus::Client.registry.get(metric_name.to_sym)
    end

    def histogram_values_to_h(histogram, expected_labels)
      histogram_values = histogram.values[expected_labels]
      histogram_values.transform_values(&:get)
    end
end

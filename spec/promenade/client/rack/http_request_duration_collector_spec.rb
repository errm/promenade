require "spec_helper"
require "promenade/client/rack/http_request_duration_collector"
require "rack/mock"
require "support/test_rack_app"

RSpec.describe Promenade::Client::Rack::HTTPRequestDurationCollector, reset_prometheus_client: true do
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

    it "records a histogram for the response time" do
      env = Rack::MockRequest.env_for
      app = TestRackApp.new
      middleware = described_class.new(app)

      histogram = fetch_metric(:http_req_duration_seconds)
      expect(histogram).to receive(:observe)

      middleware.call(env)
    end

    it "records a histogram with code, controller_action, host, and method labels" do
      env = Rack::MockRequest.env_for("/test-path",
        "HTTP_HOST" => "test.host",
        "action_dispatch.request.parameters" => {
          "controller" => "test_controller",
          "action" => "test_action",
        },
        method: :post)
      app = TestRackApp.new(status: 201)
      middleware = described_class.new(app)

      expected_duration = 1.0
      histogram = fetch_metric(:http_req_duration_seconds)
      expected_labels = {
        code: "201",
        controller_action: "test_controller#test_action",
        host: "test.host",
        method: "post",
      }

      expect(middleware).to receive(:current_time).and_return(1.0, 2.0)
      expect(histogram).to receive(:observe).with(expected_labels, expected_duration)

      middleware.call(env)
    end

    it "accepts a custom block for Histogram labels" do
      env = Rack::MockRequest.env_for("/", "fizz" => "buzz")
      app = TestRackApp.new
      custom_label_builder = proc { |_env| { foo: "bar", fizz: _env["fizz"] } }
      middleware = described_class.new(app, label_builder: custom_label_builder)

      expected_duration = 1.0
      histogram = fetch_metric(:http_req_duration_seconds)
      expected_labels = { foo: "bar", fizz: "buzz", code: "200" }

      expect(middleware).to receive(:current_time).and_return(1.0, 2.0)
      expect(histogram).to receive(:observe).with(expected_labels, expected_duration)

      middleware.call(env)
    end

    it "increments the exceptions counter if status code is an error" do
      env = Rack::MockRequest.env_for("/", "fizz" => "buzz")
      app = proc { raise(StandardError, "Status code 500") }
      middleware = described_class.new(app)
      counter = fetch_metric(:http_exceptions_total)

      expect(counter).to receive(:increment).with(exception: "StandardError")

      expect { middleware.call(env) }.to raise_error(StandardError)
    end

    it "calls the custom exception block if provided" do
      test_handler = double("handler")
      env = Rack::MockRequest.env_for("/", "fizz" => "buzz")
      app = proc { |_| raise(StandardError, "Status code 500") }
      exception_handler = proc { |exception| test_handler.received_exception(exception.message) }
      middleware = described_class.new(app, exception_handler: exception_handler)

      expect(test_handler).to receive(:received_exception).with("Status code 500")

      middleware.call(env)
    end

    it "accepts a custom set of histogram buckets" do
      Promenade.configure do |config|
        config.rack_latency_buckets = [1.0, 1.5, 2.0]
      end

      env = Rack::MockRequest.env_for
      app = TestRackApp.new
      middleware = described_class.new(app)
      expected_labels = { code: "200", controller_action: "unknown#unknown", host: "", method: "get" }
      histogram = fetch_metric(:http_req_duration_seconds)

      expect(middleware).to receive(:duration_since).and_return(1.5)

      middleware.call(env)

      normalized_histogram_values = histogram_values_to_h(histogram, expected_labels)
      expect(normalized_histogram_values).to eq({ 1.0 => 0.0, 1.5 => 1.0, 2.0 => 1.0 })
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

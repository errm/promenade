require "spec_helper"
require "promenade/client/rack/collector"
require "rack/mock"
require "support/test_rack_app"

RSpec.describe Promenade::Client::Rack::Collector, reset_prometheus_client: true do
  describe "#call" do
    it "preserves the status code" do
      env = Rack::MockRequest.env_for
      app = TestRackApp.new(status: 418)
      middleware = Promenade::Client::Rack::Collector.new(app)
      status, = middleware.call(env)

      expect(status).to eql(418)
    end

    it "preserves the headers" do
      env = Rack::MockRequest.env_for
      app = TestRackApp.new(headers: { "HTTP_FIZZ" => "buzz" })
      middleware = Promenade::Client::Rack::Collector.new(app)
      _, headers, = middleware.call(env)

      expect(headers).to eql("HTTP_FIZZ" => "buzz")
    end

    it "preserves the body" do
      env = Rack::MockRequest.env_for
      app = TestRackApp.new(body: "test-body")
      middleware = Promenade::Client::Rack::Collector.new(app)
      _, _, body = middleware.call(env)

      expect(body).to eql("test-body")
    end

    it "records a histogram for the response time" do
      env = Rack::MockRequest.env_for
      app = TestRackApp.new
      middleware = Promenade::Client::Rack::Collector.new(app)

      histogram = fetch_metric(:http_req_duration_seconds)
      expect(histogram).to receive(:observe)

      middleware.call(env)
    end

    it "records a histogram with code, path, host, and method labels" do
      env = Rack::MockRequest.env_for("/test-path", "HTTP_HOST" => "test.host", method: :post)
      app = TestRackApp.new(status: 201)
      middleware = Promenade::Client::Rack::Collector.new(app)

      expected_duration = 1.0
      histogram = fetch_metric(:http_req_duration_seconds)
      expected_labels = { code: "201", path: "/test-path", host: "test.host", method: "post" }

      expect(middleware).to receive(:current_time).and_return(1.0, 2.0)
      expect(histogram).to receive(:observe).with(expected_labels, expected_duration)

      middleware.call(env)
    end

    it "records a summary with code, path, host, and method labels" do
      env = Rack::MockRequest.env_for("/test-path", "HTTP_HOST" => "test.host", method: :post)
      app = TestRackApp.new(status: 201)
      middleware = Promenade::Client::Rack::Collector.new(app)

      expected_duration = 1.0
      summary = fetch_metric(:http_request_duration_seconds)
      expected_labels = { code: "201", path: "/test-path", host: "test.host", method: "post" }

      expect(middleware).to receive(:current_time).and_return(1.0, 2.0)
      expect(summary).to receive(:observe).with(expected_labels, expected_duration)

      middleware.call(env)
    end

    it "records a counter with code, path, host, and method labels" do
      env = Rack::MockRequest.env_for("/test-path", "HTTP_HOST" => "test.host", method: :post)
      app = TestRackApp.new(status: 201)
      middleware = Promenade::Client::Rack::Collector.new(app)

      counter = fetch_metric(:http_requests_total)
      expected_labels = { code: "201", path: "/test-path", host: "test.host", method: "post" }

      expect(counter).to receive(:increment).with(expected_labels)

      middleware.call(env)
    end

    it "accepts a custom block for Histogram labels" do
      env = Rack::MockRequest.env_for("/", "fizz" => "buzz")
      app = TestRackApp.new
      custom_label_builder = proc { |_env| { foo: "bar", fizz: _env["fizz"] } }
      middleware = Promenade::Client::Rack::Collector.new(app, label_builder: custom_label_builder)

      expected_duration = 1.0
      histogram = fetch_metric(:http_req_duration_seconds)
      expected_labels = { foo: "bar", fizz: "buzz", code: "200" }

      expect(middleware).to receive(:current_time).and_return(1.0, 2.0)
      expect(histogram).to receive(:observe).with(expected_labels, expected_duration)

      middleware.call(env)
    end

    it "accepts a custom block for Summary labels" do
      env = Rack::MockRequest.env_for("/", "fizz" => "buzz")
      app = TestRackApp.new
      custom_label_builder = proc { |_env| { foo: "bar", fizz: _env["fizz"] } }
      middleware = Promenade::Client::Rack::Collector.new(app, label_builder: custom_label_builder)

      expected_duration = 1.0

      summary = fetch_metric(:http_request_duration_seconds)
      expected_labels = { foo: "bar", fizz: "buzz", code: "200" }

      expect(middleware).to receive(:current_time).and_return(1.0, 2.0)
      expect(summary).to receive(:observe).with(expected_labels, expected_duration)

      middleware.call(env)
    end

    it "accepts a custom block for Counter labels" do
      env = Rack::MockRequest.env_for("/", "fizz" => "buzz")
      app = TestRackApp.new
      custom_label_builder = proc { |_env| { foo: "bar", fizz: _env["fizz"] } }
      middleware = Promenade::Client::Rack::Collector.new(app, label_builder: custom_label_builder)
      counter = fetch_metric(:http_requests_total)
      expected_labels = { foo: "bar", fizz: "buzz", code: "200" }

      expect(counter).to receive(:increment).with(expected_labels)

      middleware.call(env)
    end

    it "increments the exceptions counter if status code is an error" do
      env = Rack::MockRequest.env_for("/", "fizz" => "buzz")
      app = proc { raise(StandardError, "Status code 500") }
      middleware = Promenade::Client::Rack::Collector.new(app)
      counter = fetch_metric(:http_exceptions_total)

      expect(counter).to receive(:increment).with(exception: "StandardError")

      expect { middleware.call(env) }.to raise_error(StandardError)
    end

    it "calls the custom exception block if provided" do
      test_handler = double("handler")
      env = Rack::MockRequest.env_for("/", "fizz" => "buzz")
      app = proc { |_| raise(StandardError, "Status code 500") }
      exception_handler = proc { |exception| test_handler.received_exception(exception.message) }
      middleware = Promenade::Client::Rack::Collector.new(app, exception_handler: exception_handler)

      expect(test_handler).to receive(:received_exception).with("Status code 500")

      middleware.call(env)
    end
  end

  private

    def fetch_metric(metric_name)
      ::Prometheus::Client.registry.get(metric_name.to_sym)
    end
end

require "spec_helper"
require "promenade/client/rack/exception_handler"

RSpec.describe Promenade::Client::Rack::ExceptionHandler, reset_prometheus_client: true do
  before do
    ::Prometheus::Client.registry.tap do |register|
      register.histogram(:http_req_duration_seconds, "A histogram of the response latency.")
      register.counter(:http_requests_total, "A counter of the total number of HTTP requests made.")
      register.counter(:http_exceptions_total, "A counter of the total number of exceptions raised.")
    end
    Promenade::Client::Rack::ExceptionHandler.initialize_singleton(
      histogram_name: :http_req_duration_seconds,
      requests_counter_name: :http_requests_total,
      exceptions_counter_name: :http_exceptions_total,
      registry: ::Prometheus::Client.registry,
    )
  end

  after do
    if Promenade::Client::Rack::ExceptionHandler.instance_variables.include?(:@singleton)
      Promenade::Client::Rack::ExceptionHandler.remove_instance_variable(:@singleton)
    end
    ::Prometheus::Client.reset!
  end

  describe "#call" do
    it "adds the desired labels and values to the :http_req_duration_seconds histogram" do
      env_hash = {
        "action_dispatch.request.parameters" => {
          "controller" => "test-controller",
          "action" => "test-action",
        },
        "REQUEST_METHOD" => "post",
        "HTTP_HOST" => "test.host",
      }

      exception = exception_klass.new("Test error")
      histogram = ::Prometheus::Client.registry.get(:http_req_duration_seconds)
      request_duration_seconds = 1.0

      expect(histogram).to receive(:observe).with({
        controller_action: "test-controller#test-action",
        method: "post",
        host: "test.host",
        code: "500",
      }, request_duration_seconds)
      expect {
        Promenade::Client::Rack::ExceptionHandler.call(exception, env_hash, request_duration_seconds)
      }.to raise_error(exception_klass)
    end

    it "adds the desired labels and values to the :http_requests_total counter" do
      env_hash = {
        "action_dispatch.request.parameters" => {
          "controller" => "test-controller",
          "action" => "test-action",
        },
        "REQUEST_METHOD" => "post",
        "HTTP_HOST" => "test.host",
      }

      exception = exception_klass.new("Test error")
      requests_counter = ::Prometheus::Client.registry.get(:http_requests_total)
      request_duration_seconds = 1.0

      expect(requests_counter).to receive(:increment).with({
        controller_action: "test-controller#test-action",
        method: "post",
        host: "test.host",
        code: "500",
      })
      expect {
        Promenade::Client::Rack::ExceptionHandler.call(exception, env_hash, request_duration_seconds)
      }.to raise_error(exception_klass)
    end

    it "adds the exception to the http_exceptions_total counter" do
      env_hash = {
        "action_dispatch.request.parameters" => {
          "controller" => "test-controller",
          "action" => "test-action",
        },
        "REQUEST_METHOD" => "post",
        "HTTP_HOST" => "test.host",
      }

      exception = exception_klass.new("Test error")
      exceptions_counter = ::Prometheus::Client.registry.get(:http_exceptions_total)
      request_duration_seconds = 1.0

      expect(exceptions_counter).to receive(:increment).with(exception: "ExceptionKlass")
      expect {
        Promenade::Client::Rack::ExceptionHandler.call(exception, env_hash, request_duration_seconds)
      }.to raise_error(exception_klass)
    end

    it "re-raises the exception" do
      env_hash = {}
      exception = exception_klass.new("Test error")
      exception_counter = ::Prometheus::Client.registry.get(:http_exceptions_total)
      request_duration_seconds = 1.0

      expect(Proc.new do
        Promenade::Client::Rack::ExceptionHandler.call(exception,
          env_hash,
          request_duration_seconds)
      end).to raise_error(exception_klass)
    end
  end

  private

    def exception_klass
      @_exception_klass ||= Class.new(StandardError) do
        def self.name
          "ExceptionKlass"
        end
      end
    end
end

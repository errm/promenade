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
    let(:env_hash) do
      {
        "action_dispatch.request.parameters" => {
          "controller" => "test-controller",
          "action" => "test-action",
        },
        "REQUEST_METHOD" => "post",
        "HTTP_HOST" => "test.host",
      }
    end

    let(:exception) { exception_klass.new("Test error") }


    let(:request_duration_seconds) { 1.0 }


    it "adds the desired labels and values to the :http_req_duration_seconds histogram" do
      histogram = ::Prometheus::Client.registry.get(:http_req_duration_seconds)
      expected_labels = {
        controller_action: "test-controller#test-action",
        method: "post",
        host: "test.host",
        code: "500",
      }

      expect do
        Promenade::Client::Rack::ExceptionHandler.call(exception, env_hash, request_duration_seconds)
      end.to raise_error(exception_klass)

      expect(histogram).to have_time_series_value(1.0).
        for_buckets_greater_than_or_equal_to(request_duration_seconds).
        with_labels(expected_labels)
    end

    it "adds the exception to the http_exceptions_total counter" do
      exceptions_counter = ::Prometheus::Client.registry.get(:http_exceptions_total)

      expect do
        Promenade::Client::Rack::ExceptionHandler.call(exception, env_hash, request_duration_seconds)
      end.to raise_error(exception_klass)

      expect(exceptions_counter).to have_time_series_count(1.0).with_labels(exception: "ExceptionKlass")
    end

    it "re-raises the exception" do
      env_hash = {}

      exception_counter = ::Prometheus::Client.registry.get(:http_exceptions_total)

      expect do
        Promenade::Client::Rack::ExceptionHandler.call(exception,
          env_hash,
          request_duration_seconds)
      end.to raise_error(exception_klass)
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

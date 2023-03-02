require "prometheus/client"
require_relative "middleware_base"
require_relative "request_controller_action_labeler"
require_relative "exception_handler"
require_relative "queue_time_duration"

module Promenade
  module Client
    module Rack
      class HTTPRequestDurationCollector < MiddlwareBase
        REQUEST_DURATION_HISTOGRAM_NAME = :http_req_duration_seconds

        REQUESTS_COUNTER_NAME = :http_requests_total

        EXCEPTIONS_COUNTER_NAME = :http_exceptions_total

        private_constant :REQUEST_DURATION_HISTOGRAM_NAME,
          :REQUESTS_COUNTER_NAME,
          :EXCEPTIONS_COUNTER_NAME

        def initialize(app,
                       registry: ::Prometheus::Client.registry,
                       label_builder: RequestControllerActionLabeler,
                       exception_handler: nil)

          @latency_buckets = Promenade.configuration.rack_latency_buckets
          @_exception_handler = exception_handler

          super(app, registry: registry, label_builder: label_builder)
        end

        private

          attr_reader :latency_buckets, :queue_time_buckets

          def trace(env)
            start = current_time
            begin
              response = yield
              record_request_duration(labels(env, response), duration_since(start))
              response
            rescue StandardError => e
              exception_handler.call(e, env, duration_since(start))
            end
          end

          def record_request_duration(labels, duration)
            requests_counter.increment(labels)
            durations_histogram.observe(labels, duration)
          end

          def duration_since(start_time)
            current_time - start_time
          end

          def current_time
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end

          def durations_histogram
            registry.get(REQUEST_DURATION_HISTOGRAM_NAME)
          end

          def requests_counter
            registry.get(REQUESTS_COUNTER_NAME)
          end

          def register_metrics!
            registry.counter(REQUESTS_COUNTER_NAME,
              "A counter of the total number of HTTP requests made.")
            registry.histogram(REQUEST_DURATION_HISTOGRAM_NAME,
              "A histogram of the response latency.", {}, latency_buckets)
            registry.counter(EXCEPTIONS_COUNTER_NAME,
              "A counter of the total number of exceptions raised.")
          end

          def exception_handler
            @_exception_handler ||= default_exception_handler
          end

          def default_exception_handler
            ExceptionHandler.initialize_singleton(
              histogram_name: REQUEST_DURATION_HISTOGRAM_NAME,
              requests_counter_name: REQUESTS_COUNTER_NAME,
              exceptions_counter_name: EXCEPTIONS_COUNTER_NAME,
              registry: registry,
            )
          end
      end
    end
  end
end

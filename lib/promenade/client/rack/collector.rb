require "prometheus/client"
require_relative "request_labeler"
require_relative "exception_handler"

module Promenade
  module Client
    module Rack
      # Original code taken from Prometheus Client MMap
      # https://gitlab.com/gitlab-org/prometheus-client-mmap/-/blob/master/lib/prometheus/client/rack/collector.rb
      #
      # Collector is a Rack middleware that provides a sample implementation of
      # a HTTP tracer. The default label builder can be modified to export a
      # different set of labels per recorded metric.
      class Collector
        REQUEST_METHOD = "REQUEST_METHOD".freeze

        HTTP_HOST = "HTTP_HOST".freeze

        PATH_INFO = "PATH_INFO".freeze

        HISTOGRAM_NAME = :http_req_duration_seconds

        REQUESTS_COUNTER_NAME = :http_requests_total

        EXCEPTIONS_COUNTER_NAME = :http_exceptions_total

        private_constant *%i(
          REQUEST_METHOD
          HTTP_HOST
          PATH_INFO
          HISTOGRAM_NAME
          REQUESTS_COUNTER_NAME
          EXCEPTIONS_COUNTER_NAME
        )

        def initialize(app,
                       registry: ::Prometheus::Client.registry,
                       label_builder: RequestLabeler,
                       exception_handler: nil)
          @app = app
          @registry = registry
          @label_builder = label_builder
          @exception_handler = exception_handler
          register_metrics!
        end

        def call(env)
          trace(env) { app.call(env) }
        end

        private

          attr_reader :app,
            :registry,
            :label_builder

          def trace(env)
            start = current_time
            response = yield
            finish = current_time
            duration = finish - start
            record(labels(env, response), duration)
            response
          rescue StandardError => e
            exception_handler.call(e, env, duration)
          end

          def labels(env, response)
            label_builder.call(env).merge!(code: response.first.to_s)
          end

          def record(labels, duration)
            requests_counter.increment(labels)
            durations_histogram.observe(labels, duration)
          end

          def current_time
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end

          def durations_histogram
            registry.get(HISTOGRAM_NAME)
          end

          def requests_counter
            registry.get(REQUESTS_COUNTER_NAME)
          end

          def register_metrics!
            registry.counter(REQUESTS_COUNTER_NAME, "A counter of the total number of HTTP requests made.")
            registry.histogram(HISTOGRAM_NAME, "A histogram of the response latency.")
            registry.counter(EXCEPTIONS_COUNTER_NAME, "A counter of the total number of exceptions raised.")
          end

          # rubocop:disable Naming/MemoizedInstanceVariableName
          def exception_handler
            @exception_handler ||= default_exception_handler
          end
          # rubocop:enable Naming/MemoizedInstanceVariableName

          def default_exception_handler
            ExceptionHandler.initialize_singleton(
              histogram_name: HISTOGRAM_NAME,
              requests_counter_name: REQUESTS_COUNTER_NAME,
              exceptions_counter_name: EXCEPTIONS_COUNTER_NAME,
              registry: registry,
            )
          end
      end
    end
  end
end

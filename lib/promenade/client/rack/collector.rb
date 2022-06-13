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

        DEFAULT_LABEL_BUILDER = RequestLabeler.singleton

        DEFAULT_EXCEPTION_HANDLER = ExceptionHandler.initialize_singleton(
          histogram_name: HISTOGRAM_NAME,
          requests_counter_name: COUNTER_NAME,
          exceptions_counter_name: EXCEPTIONS_COUNTER_NAME,
          registry: ::Prometheus::Client.registry,
        )

        private_constant *%i(
          REQUEST_METHOD
          HTTP_HOST
          PATH_INFO
          DEFAULT_LABEL_BUILDER
          HISTOGRAM_NAME
          REQUESTS_COUNTER_NAME
          EXCEPTIONS_COUNTER_NAME
          DEFAULT_EXCEPTION_HANDLER
        )

        def initialize(app,
                       registry: ::Prometheus::Client.registry,
                       label_builder: DEFAULT_LABEL_BUILDER,
                       exception_handler: DEFAULT_EXCEPTION_HANDLER)
          @app = app
          @registry = registry
          @label_builder = label_builder
          @exception_handler = exception_handler

          @requests_counter = registry.counter(REQUESTS_COUNTER_NAME,
            "A counter of the total number of HTTP requests made.")
          @durations_histogram = registry.histogram(HISTOGRAM_NAME, "A histogram of the response latency.")
          @exceptions_counter = registry.counter(EXCEPTIONS_COUNTER_NAME,
            "A counter of the total number of exceptions raised.")
        end

        def call(env)
          trace(env) { app.call(env) }
        end

        private

          attr_reader :app,
            :registry,
            :label_builder,
            :exception_handler,
            :durations_histogram,
            :requests_counter,
            :exceptions_counter

          def trace(env)
            start = current_time
            response = yield
            finish = current_time
            duration = finish - start
            record(labels(env, response), duration)
            response
          rescue StandardError => e
            exception_handler.call(e, exceptions_counter, env, duration)
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
      end
    end
  end
end

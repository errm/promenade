require "prometheus/client"

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
        private_constant :REQUEST_METHOD

        HTTP_HOST = "HTTP_HOST".freeze
        private_constant :HTTP_HOST

        PATH_INFO = "PATH_INFO".freeze
        private_constant :PATH_INFO

        DEFAULT_LABEL_BUILDER = proc do |env|
          {
            method: env[REQUEST_METHOD].downcase,
            host:   env[HTTP_HOST].to_s,
            path:   env[PATH_INFO].to_s,
          }
        end
        private_constant :DEFAULT_LABEL_BUILDER

        DEFAULT_EXCEPTION_HANDLER = proc do |exception, counter|
          counter.increment(exception: exception.class.name)
          raise exception
        end
        private_constant :DEFAULT_EXCEPTION_HANDLER

        def initialize(app,
                       registry: ::Prometheus::Client.registry,
                       label_builder: DEFAULT_LABEL_BUILDER,
                       exception_handler: DEFAULT_EXCEPTION_HANDLER)
          @app = app
          @registry = registry
          @label_builder = label_builder
          @exception_handler = exception_handler

          @requests_counter = registry.counter(
            :http_requests_total,
            "A counter of the total number of HTTP requests made.",
          )
          @durations_summary = registry.summary(
            :http_request_duration_seconds,
            "A summary of the response latency.",
          )
          @durations_histogram = registry.histogram(
            :http_req_duration_seconds,
            "A histogram of the response latency.",
          )
          @exceptions_counter = registry.counter(
            :http_exceptions_total,
            "A counter of the total number of exceptions raised.",
          )
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
            :durations_summary,
            :requests_counter,
            :exceptions_counter

          def trace(env)
            start = current_time
            yield.tap do |response|
              finish = current_time
              duration = finish - start
              record(labels(env, response), duration)
            end
          rescue StandardError => e
            exception_handler.call(e, exceptions_counter)
          end

          def labels(env, response)
            label_builder.call(env).merge!(code: response.first.to_s)
          end

          def record(labels, duration)
            requests_counter.increment(labels)
            durations_summary.observe(labels, duration)
            durations_histogram.observe(labels, duration)
          rescue StandardError => e
            exception_handler.call(e, exceptions_counter)
          end

          def current_time
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end
      end
    end
  end
end

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
        attr_reader :app, :registry, :label_builder, :exception_handler

        DEFAULT_LABEL_BUILDER = proc do |env|
          {
            method: env["REQUEST_METHOD"].downcase,
            host:   env["HTTP_HOST"].to_s,
            path:   env["PATH_INFO"].to_s,
          }
        end
        private_constant :DEFAULT_LABEL_BUILDER

        DEFAULT_EXCEPTION_HANDLER = proc do |exception|
          @exceptions.increment(exception: exception.class.name)
        end
        private_constant :DEFAULT_EXCEPTION_HANDLER

        def initialize(app,
                       options: {},
                       label_builder: DEFAULT_LABEL_BUILDER,
                       exception_handler: DEFAULT_EXCEPTION_HANDLER)
          @app = app
          @registry = options[:registry] || ::Prometheus::Client.registry
          @label_builder = label_builder
          @exception_handler = exception_handler

          init_request_metrics
        end

        def call(env) # :nodoc:
          trace(env) { @app.call(env) }
        end

        protected

          def init_request_metrics
            @registry.reset!
            @requests = @registry.counter(
              :http_requests_total,
              "A counter of the total number of HTTP requests made.",
            )
            @durations = @registry.summary(
              :http_request_duration_seconds,
              "A summary of the response latency.",
            )
            @durations_hist = @registry.histogram(
              :http_req_duration_seconds,
              "A histogram of the response latency.",
            )
          end

          def exceptions
            @_exceptions ||= @registry.counter(
              :http_exceptions_total,
              "A counter of the total number of exceptions raised.",
            )
          end

          def trace(env)
            start = Time.now
            yield.tap do |response|
              duration = (Time.now - start).to_f
              record(labels(env, response), duration)
            end
          rescue StandardError => e
            DEFAULT_EXCEPTION_HANDLER.call(e, exception_handler)
          end

          def labels(env, response)
            @label_builder.call(env).tap do |labels|
              labels[:code] = response.first.to_s
            end
          end

          def record(labels, duration)
            @requests.increment(labels)
            @durations.observe(labels, duration)
            @durations_hist.observe(labels, duration)

          rescue StandardError => e
            DEFAULT_EXCEPTION_HANDLER.call(e, exception_handler)
          end
      end
    end
  end
end

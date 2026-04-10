require "prometheus/client"
require_relative "middleware_base"
require_relative "request_labeler"
require_relative "queue_time_duration"

module Promenade
  module Client
    module Rack
      class HTTPRequestQueueTimeCollector < MiddlwareBase
        REQUEST_QUEUE_TIME_HISTOGRAM_NAME = :http_request_queue_time_seconds

        private_constant :REQUEST_QUEUE_TIME_HISTOGRAM_NAME

        def initialize(app,
                       registry: ::Prometheus::Client.registry,
                       label_builder: RequestLabeler)
          @queue_time_buckets = Promenade.configuration.queue_time_buckets

          super
        end

        private

          attr_reader :queue_time_buckets

          def trace(env)
            start_timestamp = Time.now.utc
            response = yield
            record_request_queue_time(labels: labels(env, response),
              env: env,
              request_received_time: start_timestamp)
            response
          end

          def record_request_queue_time(labels:, env:, request_received_time:)
            queue_time_seconds = QueueTimeDuration.new(env:, request_received_time:).queue_time_seconds
            queue_time_seconds && queue_time_histogram.observe(labels, queue_time_seconds)
          end

          def register_metrics!
            registry.histogram(REQUEST_QUEUE_TIME_HISTOGRAM_NAME,
              "A histogram of request queue time", {}, queue_time_buckets)
          end

          def queue_time_histogram
            registry.get(REQUEST_QUEUE_TIME_HISTOGRAM_NAME)
          end

          def labels(env, _)
            label_builder.call(env)
          end
      end
    end
  end
end

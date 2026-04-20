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
          super
        end

        private

          def trace(env)
            record_request_queue_time(env:)
            yield
          end

          def record_request_queue_time(env:)
            queue_time_seconds = QueueTimeDuration.new(env:).queue_time_seconds
            queue_time_seconds && queue_time_histogram.observe(label_builder.call(env), queue_time_seconds)
          end

          def register_metrics!
            registry.histogram(REQUEST_QUEUE_TIME_HISTOGRAM_NAME,
              "A histogram of request queue time", {}, Promenade.configuration.queue_time_buckets)
          end

          def queue_time_histogram
            registry.get(REQUEST_QUEUE_TIME_HISTOGRAM_NAME)
          end
      end
    end
  end
end

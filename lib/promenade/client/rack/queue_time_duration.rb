module Promenade
  module Client
    module Rack
      class QueueTimeDuration
        REQUEST_START_HEADER = "HTTP_X_REQUEST_START".freeze
        QUEUE_START_HEADER = "HTTP_X_QUEUE_START".freeze

        HEADER_VALUE_MATCHER = /^(?:t=)(?<timestamp>\d{10}(?:\.\d+))$/

        def initialize(env:, request_received_time: Time.now.utc)
          @request_enqueued_time = request_enqueued_time_from(env)
          @request_received_time = request_received_time.utc.to_f
          freeze
        end

        def queue_time_seconds
          # Enqueued time could not be parsed from headers
          return unless request_enqueued_time

          # A negative queue time is not valid
          return if queue_time < 0

          queue_time.round(3)
        end

        private

          attr_reader :request_enqueued_time, :request_received_time

          def queue_time
            request_received_time - request_enqueued_time
          end

          def request_enqueued_time_from(env)
            header_value = env.values_at(REQUEST_START_HEADER, QUEUE_START_HEADER).compact.first
            return if header_value.nil?

            header_time_match = header_value.to_s.match(HEADER_VALUE_MATCHER)
            return unless header_time_match

            header_time_match[:timestamp].to_f
          end
      end
    end
  end
end

module Promenade
  module Client
    module Rack
      class QueueTimeDuration
        REQUEST_START_HEADER = "HTTP_X_REQUEST_START".freeze

        QUEUE_START_HEADER = "HTTP_X_QUEUE_START".freeze

        HEADER_VALUE_MATCHER = /^(?:t=)(?<timestamp>\d{10}(?:\.\d+))$/.freeze

        MILLISECONDS_PER_SECOND = 1_000

        def initialize(env:, request_received_time:)
          @env = env
          @request_queued_time_ms = extract_request_queued_time_from_env(env)
          @valid_header_present = @request_queued_time_ms.is_a?(Float)
          @request_received_time_ms = request_received_time.utc.to_f

          freeze
        end

        def valid_header_present?
          !!@valid_header_present
        end

        def queue_time_seconds
          return unless valid_header_present?

          queue_time.round(3)
        end

        private

          attr_reader :env, :request_queued_time_ms, :request_received_time_ms

          def queue_time
            request_received_time_ms - request_queued_time_ms
          end

          def extract_request_queued_time_from_env(env_hash)
            header_value = env_hash[REQUEST_START_HEADER] || env_hash[QUEUE_START_HEADER]
            return if header_value.nil?

            header_time_match = header_value.to_s.match(HEADER_VALUE_MATCHER)
            return unless header_time_match

            header_time_match[:timestamp].to_f
          end
      end
    end
  end
end

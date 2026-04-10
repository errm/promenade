module Promenade
  module Client
    module Rack
      class QueueTimeDuration
        REQUEST_START_HEADER = "HTTP_X_REQUEST_START".freeze
        QUEUE_START_HEADER = "HTTP_X_QUEUE_START".freeze

        HEADER_VALUE_MATCHER = /^(?:t=)(?<timestamp>\d{10}(?:\.\d+))$/

        def initialize(env:, request_received_time:)
          @request_queued_time = extract_request_queued_time_from_env(env)
          @request_received_time = request_received_time.utc.to_f
          freeze
        end

        def queue_time_seconds
          queue_time&.round(3)
        end

        private

          attr_reader :request_queued_time, :request_received_time

          def queue_time
            return unless request_queued_time
            request_received_time - request_queued_time
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

require "promenade/karafka/subscriber"

module Promenade
  module Karafka
    class ErrorSubscriber < Subscriber
      attach_to "error.kafka"

      def occurred(event)
        error = {
          error: event.payload[:error],
          client: Karafka::App.config.client_id
        }

        Rails.logger.error "[Error] error occurred: #{error.inspect}"
        Rails.logger.error "[Error] error inspected: #{event.payload.inspect}"
      end
    end
  end
end

require "promenade/karafka/subscriber"

module Promenade
  module Karafka
    class ErrorSubscriber < Subscriber
      attach_to "error.karafka"

      def occurred(event)
        error = {
          error: event.payload[:error]
        }

        Rails.logger.error "[Error][karafka] error occurred: #{error.inspect}"
        Rails.logger.error "[Error][karafka] error inspected: #{event.payload.inspect}"
      end
    end
  end
end

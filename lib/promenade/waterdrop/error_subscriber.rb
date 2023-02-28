require "promenade/karafka/subscriber"

module Promenade
  module Waterdrop
    class ErrorSubscriber < Subscriber
      attach_to "error.waterdrop"

      def occurred(event)
        error = {
          error: event.payload[:error]
        }

        Rails.logger.error "[Error][waterdrop] error occurred: #{error.inspect}"
        Rails.logger.error "[Error][waterdrop] error inspected: #{event.payload.inspect}"
      end
    end
  end
end

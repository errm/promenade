require "promenade/waterdrop/subscriber"

module Promenade
  module Waterdrop
    class ErrorSubscriber < Subscriber
      attach_to "error.waterdrop"

      Promenade.counter :waterdrop_errors do
        doc "Count of Waterdrop errors"
      end

      def occurred(event)
        labels = get_labels(event)

        Promenade.metric(:waterdrop_errors).increment(labels)
        Rails.logger.error "[Error][Waterdrop] error occurred: #{labels}"
      end

      private

        def get_labels(event)
          {
            error_type: event.payload[:type]
          }
        end
    end
  end
end

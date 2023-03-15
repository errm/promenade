require "promenade/waterdrop/subscriber"

module Promenade
  module Waterdrop
    class ErrorSubscriber < Subscriber
      attach_to "error.waterdrop"

      Promenade.counter :waterdrop_errors_total do
        doc "Count of Waterdrop errors"
      end

      def occurred(event)
        labels = get_labels(event)

        Promenade.metric(:waterdrop_errors_total).increment(labels)
      end

      private

        def get_labels(event)
          {
            error_type: event.payload[:type],
          }
        end
    end
  end
end

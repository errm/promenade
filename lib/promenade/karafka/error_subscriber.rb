require "promenade/karafka/subscriber"

module Promenade
  module Karafka
    class ErrorSubscriber < Subscriber
      attach_to "error.karafka"

      Promenade.counter :kafka_errors do
        doc "Count of Kafka connection errors"
      end

      def occurred(event)
        label = {
          error_type: event[:type]
        }

        Promenade.metric(:kafka_errors).increment(label)
        Rails.logger.error "[Error][karafka] error occurred: #{label}"
      end
    end
  end
end

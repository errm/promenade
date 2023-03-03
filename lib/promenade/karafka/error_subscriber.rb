require "promenade/karafka/subscriber"

module Promenade
  module Karafka
    class ErrorSubscriber < Subscriber
      attach_to "error.karafka"

      Promenade.counter :karafka_errors do
        doc "Count of Kafka connection errors"
      end

      def occurred(event)
        labels = get_labels(event)

        Promenade.metric(:karafka_errors).increment(labels)
        $stdout.puts "[Error][karafka] error occurred: #{labels}"
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

require "promenade/waterdrop/subscriber"

module Promenade
  module Waterdrop
    class MessageSubscriber < Subscriber
      attach_to "message.waterdrop"

      Promenade.counter :waterdrop_producer_messages do
        doc "Number of messages written to Kafka producer"
      end

      Promenade.counter :waterdrop_producer_ack_messages do
        doc "Count of the number of messages Acked by Kafka"
      end

      def produced_async(event)
        Promenade.metric(:waterdrop_producer_messages).increment(get_labels(event))
      end

      def produced_sync(event)
        Promenade.metric(:waterdrop_producer_messages).increment(get_labels(event))
      end

      def acknowledged(event)
        labels = {
          client: event.payload[:producer_id],
        }

        Promenade.metric(:waterdrop_producer_ack_messages).increment(labels)
      end

      private

        def get_labels(event)
          payload = event.payload

          {
            client: payload[:producer_id],
            topic: event.payload[:message][:topic],
          }
        end
    end
  end
end

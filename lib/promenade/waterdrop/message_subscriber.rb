require "promenade/waterdrop/subscriber"

module Promenade
  module Waterdrop
    class MessageSubscriber < Subscriber
      attach_to "message.waterdrop"

      Promenade.counter :kafka_producer_messages do
        doc "Number of messages written to Kafka producer"
      end

      Promenade.counter :kafka_producer_ack_messages do
        doc "Count of the number of messages Acked by Kafka"
      end

      def produced_async(event)
        data = event.payload[:message].slice(:key, :topic).merge(producer_id: event.payload[:producer_id])

        Rails.logger.info("[waterdrop] produced_async: #{data.inspect}")
        Promenade.metric(:kafka_producer_messages).increment(get_labels(event))
      end

      def produced_sync(event)
        data = event.payload[:message].slice(:key, :topic).merge(producer_id: event.payload[:producer_id])

        Rails.logger.info("[waterdrop] produced_sync: #{data.inspect}")
        Promenade.metric(:kafka_producer_messages).increment(get_labels(event))
      end

      def acknowledged(event)
        labels = {
          client: event.payload[:producer_id]
        }

        Rails.logger.info "[waterdrop] message acknowledged: #{event.payload.inspect}"
        Promenade.metric(:kafka_producer_ack_messages).increment(labels)
      end

      private

        def get_labels(event)
          payload = event.payload

          {
            client: payload[:producer_id],
            topic: event.payload[:message][:topic]
          }
        end
    end
  end
end

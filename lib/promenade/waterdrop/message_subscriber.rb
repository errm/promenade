require "promenade/waterdrop/subscriber"

module Promenade
  module Waterdrop
    class MessageSubscriber < Subscriber
      attach_to "message.waterdrop"

      def produced_async(event)
        data = event.payload[:message].slice(:key, :topic).merge(producer_id: event.payload[:producer_id])
        # Promenade.metric(:kafka_producer_messages).increment(labels)

        Rails.logger.info("[waterdrop] produced_async: #{data.inspect}")
      end

      def produced_sync(event)
        data = event.payload[:message].slice(:key, :topic).merge(producer_id: event.payload[:producer_id])
        # Promenade.metric(:kafka_producer_messages).increment(labels)

        Rails.logger.info("[waterdrop] produced_sync: #{data.inspect}")
      end

      def acknowledged(event)
        Rails.logger.info "[waterdrop] message acknowledged: #{event.payload.inspect}"
        # Promenade.metric(:kafka_producer_ack_messages).increment(labels)

      end
    end
  end
end

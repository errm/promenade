require "promenade/karafka/subscriber"

module Promenade
  module Karafka
    class ConsumerSubscriber < Subscriber
      attach_to "consumer.karafka"

      Promenade.histogram :kafka_consumer_batch_processing_latency do
        doc "Consumer message processing latency"
        buckets :network
      end

      Promenade.counter :kafka_consumer_messages_processed do
        doc "Messages processed by this consumer"
      end

      def consumed(event)
        consumer = event.payload[:caller]
        messages = consumer.messages
        metadata = messages.metadata

        labels = get_labels(consumer)

        Promenade.metric(:kafka_consumer_messages_processed).increment(labels, messages.size)
        Rails.logger.info "[Consumer][karafka] messages processed: #{messages.size}"

        Promenade.metric(:kafka_consumer_batch_processing_latency).observe(labels, event.time)
        Rails.logger.info "[Consumer][karafka] batch processing latency: #{event.time}ms"
      end

      private

        def get_labels(consumer)
          metadata = consumer.messages.metadata

          {
            group: consumer.topic.consumer_group.id,
            topic: metadata.topic,
            partition: metadata.partition,
          }
        end
    end
  end
end

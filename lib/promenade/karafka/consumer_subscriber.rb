require "promenade/karafka/subscriber"

module Promenade
  module Karafka
    class ConsumerSubscriber < Subscriber
      attach_to "consumer.karafka"

      Promenade.histogram :karafka_consumer_batch_processing_duration_seconds do
        doc "Consumer message processing latency in seconds"
        buckets :network
      end

      Promenade.counter :karafka_consumer_messages_processed do
        doc "Messages processed by this consumer"
      end

      def consumed(event)
        consumer = event.payload[:caller]
        messages = consumer.messages
        batch_processing_duration = convert_milliseconds_to_seconds(event.payload[:time])

        labels = get_labels(consumer)

        Promenade.metric(:karafka_consumer_messages_processed).increment(labels, messages.size)
        Promenade.metric(:karafka_consumer_batch_processing_duration_seconds).observe(labels, batch_processing_duration)
      end

      private

        def get_labels(consumer)
          metadata = consumer.messages.metadata

          {
            client: consumer.topic.kafka[:"client.id"],
            group: consumer.topic.consumer_group.id,
            topic: metadata.topic,
            partition: metadata.partition,
          }
        end

        def convert_milliseconds_to_seconds(time_in_milliseconds)
          time_in_milliseconds / 1000.to_f
        end
    end
  end
end

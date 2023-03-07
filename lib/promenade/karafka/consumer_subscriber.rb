require "promenade/karafka/subscriber"

module Promenade
  module Karafka
    class ConsumerSubscriber < Subscriber
      attach_to "consumer.karafka"

      Promenade.histogram :kafka_consumer_batch_processing_duration do
        doc "Consumer message processing latency in seconds"
        buckets :network
      end

      Promenade.counter :kafka_consumer_messages_processed do
        doc "Messages processed by this consumer"
      end

      def consumed(event)
        consumer = event.payload[:caller]
        messages = consumer.messages
        batch_processing_duration = event.payload[:time] / 1000.to_f

        labels = get_labels(consumer)

        Promenade.metric(:kafka_consumer_messages_processed).increment(labels, messages.size)
        $stdout.puts "[Consumer][karafka] messages processed: #{messages.size}"

        Promenade.metric(:kafka_consumer_batch_processing_duration).observe(labels, batch_processing_duration)
        $stdout.puts "[Consumer][karafka] batch processing duration: #{batch_processing_duration} seconds"
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
    end
  end
end

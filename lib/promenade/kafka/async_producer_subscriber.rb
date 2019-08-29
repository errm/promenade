require "promenade/kafka/subscriber"

module Promenade
  module Kafka
    class AsyncProducerSubscriber < Subscriber
      attach_to "async_producer.kafka"

      Promenade.gauge :kafka_async_producer_queue_size do
        doc "Size of Kafka async producer queue"
        labels LABELS
      end

      Promenade.gauge :kafka_async_producer_max_queue_size do
        doc "Max size of Kafka async producer queue"
        labels LABELS
      end

      Promenade.gauge :kafka_async_producer_queue_fill_ratio do
        doc "Size of Kafka async producer queue"
        labels LABELS
      end

      Promenade.counter :kafka_async_producer_buffer_overflows do
        doc "Count of buffer overflows"
        labels LABELS
      end

      Promenade.counter :kafka_async_producer_dropped_messages do
        doc "Count of dropped messages"
        labels [:client]
      end

      def enqueue_message(event)
        labels = get_labels(event)
        queue_size = event.payload.fetch(:queue_size)
        max_queue_size = event.payload.fetch(:max_queue_size)
        queue_fill_ratio = queue_size.to_f / max_queue_size

        Promenade.metric(:kafka_async_producer_queue_size).set(queue_size, labels: labels)
        Promenade.metric(:kafka_async_producer_max_queue_size).set(max_queue_size, labels: labels)
        Promenade.metric(:kafka_async_producer_queue_fill_ratio).set(queue_fill_ratio, labels: labels)
      end

      def buffer_overflow(event)
        Promenade.metric(:kafka_async_producer_buffer_overflows).increment(labels: get_labels(event))
      end

      def drop_messages(event)
        Promenade.metric(:kafka_async_producer_dropped_messages).increment(
          by: event.payload.fetch(:message_count),
          labels: { client: event.payload.fetch(:client_id) },
        )
      end
    end
  end
end

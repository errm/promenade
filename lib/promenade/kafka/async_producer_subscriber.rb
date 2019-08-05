require "promenade/kafka/subscriber"

module Promenade
  module Kafka
    class AsyncProducerSubscriber < Subscriber
      attach_to "async_producer.kafka"

      gauge :kafka_async_producer_queue_size do
        doc "Size of Kafka async producer queue"
      end

      gauge :kafka_async_producer_max_queue_size do
        doc "Max size of Kafka async producer queue"
      end

      gauge :kafka_async_producer_queue_fill_ratio do
        doc "Size of Kafka async producer queue"
      end

      counter :kafka_async_producer_buffer_overflows do
        doc "Count of buffer overflows"
      end

      counter :kafka_async_producer_dropped_messages do
        doc "Count of dropped messages"
      end

      def enqueue_message(event)
        labels = get_labels(event)
        queue_size = event.payload.fetch(:queue_size)
        max_queue_size = event.payload.fetch(:max_queue_size)
        queue_fill_ratio = queue_size.to_f / max_queue_size

        metric(:kafka_async_producer_queue_size).set(labels, queue_size)
        metric(:kafka_async_producer_max_queue_size).set(labels, max_queue_size)
        metric(:kafka_async_producer_queue_fill_ratio).set(labels, queue_fill_ratio)
      end

      def buffer_overflow(event)
        metric(:kafka_async_producer_buffer_overflows).increment(get_labels(event))
      end

      def drop_messages(event)
        client = event.payload.fetch(:client_id)
        message_count = event.payload.fetch(:message_count)

        metric(:kafka_async_producer_dropped_messages).increment({ client: client }, message_count)
      end
    end
  end
end

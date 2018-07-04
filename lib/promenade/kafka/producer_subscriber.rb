require "promenade/kafka/subscriber"

module Promenade
  module Kafka
    class ProducerSubscriber < Subscriber
      attach_to "producer.kafka"

      counter :kafka_producer_messages do
        doc "Number of messages written to Kafka producer"
      end

      histogram :kafka_producer_message_size do
        doc "Historgram of message sizes written to Kafka producer"
        buckets((0..10).map { |i| 128 * 2**i })
      end

      gauge :kafka_producer_buffer_size do
        doc "The current size of the Kafka producer buffer, in messages"
      end

      gauge :kafka_producer_buffer_fill_ratio do
        doc "The current ratio of Kafka producer buffer in use"
      end

      counter :kafka_producer_buffer_overflows do
        doc "A count of kafka producer buffer overflow errors"
      end

      counter :kafka_producer_delivery_errors do
        doc "A count of kafka producer delivery errors"
      end

      histogram :kafka_producer_delivery_latency do
        doc "Kafka producer delivery latency histogram"
        buckets :network
      end

      counter :kafka_producer_delivered_messages do
        doc "A count of the total messages delivered to Kafka"
      end

      histogram :kafka_producer_delivery_attempts do
        doc "A count of the total message deliveries attempted"
        buckets [0, 6, 12, 18, 24, 30]
      end

      counter :kafka_producer_ack_messages do
        doc "Count of the number of messages Acked by Kafka"
      end

      histogram :kafka_producer_ack_latency do
        doc "Delay between message being produced and Acked"
        buckets :network
      end

      counter :kafka_producer_ack_errors do
        doc "Count of the number of Kafka Ack errors"
      end

      def produce_message(event) # rubocop:disable Metrics/AbcSize
        labels = get_labels(event)
        message_size = event.payload.fetch(:message_size)
        buffer_size = event.payload.fetch(:buffer_size)
        max_buffer_size = event.payload.fetch(:max_buffer_size)
        buffer_fill_ratio = buffer_size.to_f / max_buffer_size.to_f

        metric(:kafka_producer_messages).increment(labels)
        metric(:kafka_producer_message_size).observe(labels, message_size)
        metric(:kafka_producer_buffer_size).set(labels.slice(:client), buffer_size)
        metric(:kafka_producer_buffer_fill_ratio).set(labels.slice(:client), buffer_fill_ratio)
      end

      def buffer_overflow(event)
        metric(:kafka_producer_buffer_overflows).increment(get_labels(event))
      end

      def deliver_messages(event) # rubocop:disable Metrics/AbcSize
        labels = { client: event.payload.fetch(:client_id) }
        message_count = event.payload.fetch(:delivered_message_count)
        attempts = event.payload.fetch(:attempts)

        metric(:kafka_producer_delivery_errors).increment(labels) if event.payload.key?(:exception)
        metric(:kafka_producer_delivery_latency).observe(labels, event.duration)
        metric(:kafka_producer_delivered_messages).increment(labels, message_count)
        metric(:kafka_producer_delivery_attempts).observe(labels, attempts)
      end

      def ack_message(event)
        labels = get_labels(event)
        delay = event.payload.fetch(:delay)

        metric(:kafka_producer_ack_messages).increment(labels)
        metric(:kafka_producer_ack_latency).observe(labels, delay)
      end

      def topic_error(event)
        client = event.payload.fetch(:client_id)
        topic = event.payload.fetch(:topic)

        metric(:kafka_producer_ack_errors).increment(client: client, topic: topic)
      end

      private

        def get_labels(event)
          client = event.payload.fetch(:client_id)
          topic = event.payload.fetch(:topic)
          { client: client, topic: topic }
        end
    end
  end
end

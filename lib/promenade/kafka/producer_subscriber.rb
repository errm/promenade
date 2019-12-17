require "promenade/kafka/subscriber"

module Promenade
  module Kafka
    class ProducerSubscriber < Subscriber
      attach_to "producer.kafka"

      Promenade.counter :kafka_producer_messages do
        doc "Number of messages written to Kafka producer"
        labels LABELS
      end

      Promenade.histogram :kafka_producer_message_size do
        doc "Historgram of message sizes written to Kafka producer"
        labels LABELS
        buckets :memory
      end

      Promenade.gauge :kafka_producer_buffer_size do
        doc "The current size of the Kafka producer buffer, in messages"
        labels [:client]
      end

      Promenade.gauge :kafka_producer_max_buffer_size do
        doc "The max size of the Kafka producer buffer"
        labels [:client]
      end

      Promenade.gauge :kafka_producer_buffer_fill_ratio do
        doc "The current ratio of Kafka producer buffer in use"
        labels [:client]
      end

      Promenade.counter :kafka_producer_buffer_overflows do
        doc "A count of kafka producer buffer overflow errors"
        labels LABELS
      end

      Promenade.counter :kafka_producer_delivery_errors do
        doc "A count of kafka producer delivery errors"
        labels [:client]
      end

      Promenade.histogram :kafka_producer_delivery_latency do
        doc "Kafka producer delivery latency histogram"
        buckets :network
        labels [:client]
      end

      Promenade.counter :kafka_producer_delivered_messages do
        doc "A count of the total messages delivered to Kafka"
        labels [:client]
      end

      Promenade.histogram :kafka_producer_delivery_attempts do
        doc "A count of the total message deliveries attempted"
        buckets [0, 6, 12, 18, 24, 30]
        labels [:client]
      end

      Promenade.counter :kafka_producer_ack_messages do
        doc "Count of the number of messages Acked by Kafka"
        labels LABELS
      end

      Promenade.histogram :kafka_producer_ack_latency do
        doc "Delay between message being produced and Acked"
        buckets :network
        labels LABELS
      end

      Promenade.counter :kafka_producer_ack_errors do
        doc "Count of the number of Kafka Ack errors"
        labels LABELS
      end

      def produce_message(event) # rubocop:disable Metrics/AbcSize
        labels = get_labels(event)
        message_size = event.payload.fetch(:message_size)
        buffer_size = event.payload.fetch(:buffer_size)
        max_buffer_size = event.payload.fetch(:max_buffer_size)
        buffer_fill_ratio = buffer_size.to_f / max_buffer_size

        Promenade.metric(:kafka_producer_messages).increment(labels: labels)
        Promenade.metric(:kafka_producer_message_size).observe(message_size, labels: labels)
        Promenade.metric(:kafka_producer_buffer_size).set(buffer_size, labels: labels.slice(:client))
        Promenade.metric(:kafka_producer_max_buffer_size).set(max_buffer_size, labels: labels.slice(:client))
        Promenade.metric(:kafka_producer_buffer_fill_ratio).set(buffer_fill_ratio, labels: labels.slice(:client))
      end

      def buffer_overflow(event)
        Promenade.metric(:kafka_producer_buffer_overflows).increment(labels: get_labels(event))
      end

      def deliver_messages(event) # rubocop:disable Metrics/AbcSize
        labels = { client: event.payload.fetch(:client_id) }
        message_count = event.payload.fetch(:delivered_message_count)
        attempts = event.payload.fetch(:attempts)

        Promenade.metric(:kafka_producer_delivery_errors).increment(labels: labels) if event.payload.key?(:exception)
        Promenade.metric(:kafka_producer_delivery_latency).observe(event.duration, labels: labels)
        Promenade.metric(:kafka_producer_delivered_messages).increment(by: message_count, labels: labels)
        Promenade.metric(:kafka_producer_delivery_attempts).observe(attempts, labels: labels)
      end

      def ack_message(event)
        labels = get_labels(event)
        delay = event.payload.fetch(:delay)

        Promenade.metric(:kafka_producer_ack_messages).increment(labels: labels)
        Promenade.metric(:kafka_producer_ack_latency).observe(delay, labels: labels)
      end

      def topic_error(event)
        client = event.payload.fetch(:client_id)
        topic = event.payload.fetch(:topic)

        Promenade.metric(:kafka_producer_ack_errors).increment(labels: { client: client, topic: topic })
      end
    end
  end
end

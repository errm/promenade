require "promenade/kafka/subscriber"

module Promenade
  module Kafka
    class ConnectionSubscriber < Subscriber
      attach_to "connection.kafka"

      LABELS = %i(api broker client).freeze

      Promenade.histogram :kafka_connection_latency do
        doc "Request latency"
        buckets :network
        labels LABELS
      end

      Promenade.counter :kafka_connection_calls do
        doc "Count of calls made to Kafka broker"
        labels LABELS
      end

      Promenade.summary :kafka_connection_request_size do
        doc "Average size of requests made to kafka"
        labels LABELS
      end

      Promenade.summary :kafka_connection_response_size do
        doc "Average size of responses made by kafka"
        labels LABELS
      end

      Promenade.counter :kafka_connection_errors do
        doc "Count of Kafka connection errors"
        labels LABELS
      end

      def request(event) # rubocop:disable Metrics/AbcSize
        labels = {
          client: event.payload.fetch(:client_id),
          api: event.payload.fetch(:api, "unknown"),
          broker: event.payload.fetch(:broker_host),
        }

        Promenade.metric(:kafka_connection_calls).increment(labels: labels)
        Promenade.metric(:kafka_connection_latency).observe(event.duration, labels: labels)

        Promenade.metric(:kafka_connection_request_size).observe(
          event.payload.fetch(:request_size, 0),
          labels: labels,
        )
        Promenade.metric(:kafka_connection_response_size).observe(
          event.payload.fetch(:response_size, 0),
          labels: labels,
        )
        Promenade.metric(:kafka_connection_errors).increment(labels: labels) if event.payload.key?(:exception)
      end
    end
  end
end

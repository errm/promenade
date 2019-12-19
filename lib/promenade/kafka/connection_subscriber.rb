require "promenade/kafka/subscriber"

module Promenade
  module Kafka
    class ConnectionSubscriber < Subscriber
      attach_to "connection.kafka"

      Promenade.histogram :kafka_connection_latency do
        doc "Request latency"
        buckets :network
      end

      Promenade.counter :kafka_connection_calls do
        doc "Count of calls made to Kafka broker"
      end

      Promenade.summary :kafka_connection_request_size do
        doc "Average size of requests made to kafka"
      end

      Promenade.summary :kafka_connection_response_size do
        doc "Average size of responses made by kafka"
      end

      Promenade.counter :kafka_connection_errors do
        doc "Count of Kafka connection errors"
      end

      def request(event) # rubocop:disable Metrics/AbcSize
        labels = {
          client: event.payload.fetch(:client_id),
          api: event.payload.fetch(:api, "unknown"),
          broker: event.payload.fetch(:broker_host),
        }

        Promenade.metric(:kafka_connection_calls).increment(labels)
        Promenade.metric(:kafka_connection_latency).observe(labels, event.duration)

        Promenade.metric(:kafka_connection_request_size).observe(labels, event.payload.fetch(:request_size, 0))
        Promenade.metric(:kafka_connection_response_size).observe(labels, event.payload.fetch(:response_size, 0))

        Promenade.metric(:kafka_connection_errors).increment(labels) if event.payload.key?(:exception)
      end
    end
  end
end

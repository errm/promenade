require "promenade/karafka/subscriber"
require "active_support/core_ext/hash"

module Promenade
  module Karafka
    class StatisticsSubscriber < Subscriber
      attach_to "statistics.karafka"

      Promenade.histogram :kafka_connection_latency_seconds do
        doc "Request latency (rtt) in milliseconds"
        buckets :network
      end

      Promenade.counter :kafka_connection_calls do
        doc "Count of calls made to Kafka broker"
      end

      Promenade.gauge :kafka_consumer_ofset_lag do
        doc "Lag between message create and consume time"
      end

      def emitted(event)
        group = event.payload[:consumer_group_id]
        statistics = event.payload[:statistics].with_indifferent_access
        client_id = statistics[:client_id]

        report_topic_metrics(statistics[:topics], group, client_id)
        report_connection_metrics(statistics[:brokers], client_id)
      end

      private

        def report_topic_metrics(topics, group, client_id)
          topics.map do |topic_name, topic_values|
            labels = {
              client: client_id,
              topic: topic_name,
              group: group,
            }
            report_partition_metrics(topic_values, labels)
          end
        end

        def report_partition_metrics(topic_values, labels)
          topic_values[:partitions].map do |partition_name, partition_values|
            next if partition_name == "-1"
            next if partition_values[:consumer_lag_stored] == -1

            labels = labels.merge(
              partition: partition_name,
            )

            offset_lag = partition_values[:consumer_lag_stored]

            Promenade.metric(:kafka_consumer_ofset_lag).set(labels, offset_lag)
          end
        end

        def report_connection_metrics(brokers, client_id)
          labels = {
            client: client_id
          }

          brokers.map do |broker_name, broker_values|
            next if broker_values[:nodeid] == -1

            rtt = convert_microseconds_to_seconds(broker_values[:rtt][:avg])
            connection_calls = broker_values[:connects]

            Promenade.metric(:kafka_connection_calls).increment(labels.merge(broker: broker_name), connection_calls)
            Promenade.metric(:kafka_connection_latency_seconds).observe(labels.merge(broker: broker_name), rtt)
          end
        end

        def convert_microseconds_to_seconds(microseconds)
          microseconds.to_f / 10**6
        end
    end
  end
end

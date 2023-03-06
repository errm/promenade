require "promenade/karafka/subscriber"
require "active_support/core_ext/hash"

module Promenade
  module Karafka
    class StatisticsSubscriber < Subscriber
      attach_to "statistics.karafka"

      Promenade.histogram :kafka_connection_latency do
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

        report_topic_metrics(statistics, group)
        report_connection_metrics(statistics)
      end

      private

        def report_topic_metrics(statistics, group)
          statistics[:topics].map do |topic_name, topic_values|
            labels = {
              client: statistics[:client_id],
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

            $stdout.puts "[Statistics][karafka Topics] #{labels} - Offset Lag: #{offset_lag}"

            Promenade.metric(:kafka_consumer_ofset_lag).set(labels, offset_lag)
          end
        end

        def report_connection_metrics(statistics) # rubocop:disable Metrics/AbcSize
          labels = {
            client: statistics[:client_id],
            api: "unknown",
          }

          statistics[:brokers].map do |broker_name, broker_values|
            next if broker_values[:nodeid] == -1

            rtt = broker_values[:rtt][:avg] / 1000
            connection_calls = broker_values[:connects]

            $stdout.puts "[Statistics][karafka Broker RTT] #{broker_name}: #{rtt}"
            $stdout.puts "[Statistics][karafka Broker Conn Calls] #{broker_name}: #{connection_calls}"

            Promenade.metric(:kafka_connection_calls).increment(labels.merge(broker: broker_name), connection_calls)
            Promenade.metric(:kafka_connection_latency).observe(labels.merge(broker: broker_name), rtt)
          end
        end
    end
  end
end

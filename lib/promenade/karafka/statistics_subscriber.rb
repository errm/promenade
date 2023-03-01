require "promenade/karafka/subscriber"

module Promenade
  module Karafka
    class StatisticsSubscriber < Subscriber
      attach_to "statistics.karafka"

      Promenade.histogram :kafka_connection_latency do
        doc "Request latency (rtt)"
        buckets :network
      end

      Promenade.counter :kafka_connection_calls do
        doc "Count of calls made to Kafka broker"
      end

      Promenade.gauge :kafka_consumer_ofset_lag do
        doc "Lag between message create and consume time"
      end

      def emitted(event)
        statistics = event.payload[:statistics].with_indifferent_access
        log_topics_data(event)
        log_consumers_data(event.payload)
        report_topic_metrics(statistics)
        report_connection_metrics(statistics)
      end

      private

        def log_topics_data(event)
          stat = event.payload[:statistics]["topics"].map do |topic_name, topic_values|
            {
              topic_name: topic_name,
              p50: topic_values["batchcnt"]["p50"],
              p95: topic_values["batchcnt"]["p95"],
              avg: topic_values["batchcnt"]["avg"],
              partitions_lag: partitions_lag(topic_values)
            }
          end

          stat.each { |st| Logger.new($stdout).info "[Statistics] #{st.inspect}" }
        end

        def partitions_lag(topic_values)
          topic_values["partitions"].map do |partition_name, partition_values|
            { partition_name: partition_name, lag: partition_values["consumer_lag"] }
          end
        end

        def log_consumers_data(payload)
          sum = payload[:statistics]["rxmsgs"]
          diff = payload[:statistics]["rxmsgs_d"]

          stat = {
            name: payload[:statistics]["name"],
            txmsgs: payload[:statistics]["txmsgs"],
            rxmsgs: payload[:statistics]["rxmsgs"],
            received_messages: sum,
            messages_from_last_statistics: diff
          }
          Logger.new($stdout).info "[Statistics][karafka] #{stat.inspect}"
        end

        def report_topic_metrics(statistics)
          statistics[:topics].map do |topic_name, topic_values|
            labels = {
              client: statistics[:client_id],
              topic: topic_name
            }

            topic_values.map do |partition_name, partition_values|
              labels = labels.merge(
                partition: partition_name
              )

              offset_lag = partition_values[:consumer_lag_stored]

              Logger.new($stdout).info "[Statistics][karafka Topics] #{labels}: #{offset_lag}"

              Promenade.metric(:kafka_consumer_ofset_lag).set(labels, offset_lag)
            end

          end
        end

        def report_connection_data(statistics)
          labels = {
            client: statistics[:client_id],
            api: "unknown"
          }

          statistics[:brokers].map do |_broker_name, broker_values|
            rtt = broker_values[:rtt][:avg]
            connection_calls = broker_values[:connects]
            broker_id = broker_values[:name]

            Logger.new($stdout).info "[Statistics][karafka Broker RTT] #{broker_id}: #{rtt}"
            Logger.new($stdout).info "[Statistics][karafka Broker Conn Calls] #{broker_id}: #{connection_calls}"

            Promenade.metric(:kafka_connection_calls).increment(labels.merge(broker: broker_id), connection_calls)
            Promenade.metric(:kafka_connection_latency).observe(labels.merge(broker: broker_id), rtt)
          end
        end
    end
  end
end

require "promenade/karafka/subscriber"

module Promenade
  module Karafka
    class StatisticsSubscriber < Subscriber
      attach_to "statistics.karafka"

      Promenade.histogram :kafka_connection_latency do
        doc "Request latency"
        buckets :network
      end

      Promenade.counter :kafka_connection_calls do
        doc "Count of calls made to Kafka broker"
      end

      def emitted(event)
        log_topics_data(event)
        log_consumers_data(event.payload)
        log_connection_data(event.payload.with_indifferent_access)
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

        def log_connection_data(payload)
          labels = {
            client: event.payload.fetch(:client_id),
            api: "unknown"
          }

          payload[:statistics][:brokers].map do |broker_name, broker_values|
            rtt = broker_values[:network][:latency][:avg][:rtt]
            connection_calls = broker_values[:network][:latency][:avg][:rtt]

            Logger.new($stdout).info "[Statistics][karafka Broker RTT] #{broker_name}: #{rtt}"
            Logger.new($stdout).info "[Statistics][karafka Broker Conn Calls] #{broker_name}: #{connection_calls}"

            Promenade.metric(:kafka_connection_calls).increment(labels.merge(broker: broker_name), connection_calls)
            Promenade.metric(:kafka_connection_latency).observe(labels.merge(broker: broker_name), rtt)
          end
        end
    end
  end
end

require "promenade/karafka/subscriber"

module Promenade
  class StatisticsSubscriber < Subscriber
    attach_to "statistics.kafka"

    def emitted(event)
      log_topics_data(event)
      log_consumers_data(event.payload)
    end

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
      Logger.new($stdout).info "[Statistics] #{stat.inspect}"
    end
  end
end

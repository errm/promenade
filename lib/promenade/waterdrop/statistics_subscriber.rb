require "promenade/waterdrop/subscriber"
require "active_support/core_ext/hash"

module Promenade
  module Waterdrop
    class StatisticsSubscriber < Subscriber
      attach_to "statistics.waterdrop"

      Promenade.histogram :waterdrop_producer_message_size do
        doc "Historgram of message sizes written to Kafka producer"
        buckets :memory
      end

      Promenade.counter :waterdrop_producer_delivered_messages do
        doc "A count of the total messages delivered to Kafka"
      end

      Promenade.histogram :waterdrop_producer_delivery_attempts do
        doc "A count of the total message deliveries attempted"
        buckets [0, 6, 12, 18, 24, 30]
      end

      Promenade.histogram :waterdrop_producer_ack_latency_seconds do
        doc "Delay between message being produced and Acked in seconds"
        buckets :network
      end

      Promenade.gauge :waterdrop_async_producer_queue_size do
        doc "Size of Kafka async producer queue"
      end

      Promenade.gauge :waterdrop_async_producer_max_queue_size do
        doc "Max size of Kafka async producer queue"
      end

      Promenade.gauge :waterdrop_async_producer_queue_fill_ratio do
        doc "Size of Kafka async producer queue"
      end

      Promenade.counter :waterdrop_async_producer_dropped_messages do
        doc "Count of dropped messages"
      end

      def emitted(event)
        statistics = event.payload[:statistics].with_indifferent_access
        labels = get_labels(statistics)

        report_root_metrics(statistics, labels)
        report_broker_metrics(statistics[:brokers], labels)
      end

      private

        def report_root_metrics(statistics, labels) # rubocop:disable Metrics/AbcSize
          queue_size = statistics[:msg_cnt]
          max_queue_size = statistics[:msg_max]
          message_size = statistics[:msg_size]
          delivered_messages = statistics[:txmsgs]
          queue_fill_ratio = queue_size.to_f / max_queue_size

          Promenade.metric(:waterdrop_async_producer_queue_size).set(labels, queue_size)
          $stdout.puts "[Statistics][Producer queue_size] #{queue_size}"
          Promenade.metric(:waterdrop_async_producer_max_queue_size).set(labels, max_queue_size)
          $stdout.puts "[Statistics][Producer max_queue_size] #{max_queue_size}"
          Promenade.metric(:waterdrop_async_producer_queue_fill_ratio).set(labels, queue_fill_ratio)
          $stdout.puts "[Statistics][Producer queue_fill_ratio] #{queue_fill_ratio}"
          Promenade.metric(:waterdrop_producer_message_size).observe(labels, message_size)
          $stdout.puts "[Statistics][Producer message_size] #{message_size}"
          Promenade.metric(:waterdrop_producer_delivered_messages).increment(labels, delivered_messages)
          $stdout.puts "[Statistics][karafka Producer Delivered Messages] #{delivered_messages}"
        end

        def report_broker_metrics(brokers, labels)
          brokers.map do |broker_name, broker_values|
            next if broker_values[:nodeid] == -1

            attempts = broker_values[:txretries]
            ack_latency = convert_microseconds_to_seconds(broker_values[:rtt][:avg])
            broker_labels = {
              broker_id: broker_name,
            }

            Promenade.metric(:waterdrop_producer_delivery_attempts).observe(labels.merge(broker_labels), attempts)
            Promenade.metric(:waterdrop_producer_ack_latency_seconds).observe(labels, ack_latency)
            $stdout.puts "[Statistics][Producer Broker ack_latency] #{ack_latency}"
            $stdout.puts "[Statistics][Producer Broker Delivery Attempts] #{broker_name}: #{attempts}"
          end
        end

        def get_labels(statistics)
          {
            client: statistics[:client_id],
          }
        end

        def convert_microseconds_to_seconds(time_in_microseconds)
          time_in_microseconds / 1_000_000.to_f
        end
    end
  end
end

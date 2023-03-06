require "promenade/waterdrop/subscriber"

module Promenade
  module Waterdrop
    class StatisticsSubscriber < Subscriber
      attach_to "statistics.waterdrop"

      Promenade.histogram :kafka_producer_message_size do
        doc "Historgram of message sizes written to Kafka producer"
        buckets :memory
      end

      Promenade.counter :kafka_producer_delivered_messages do
        doc "A count of the total messages delivered to Kafka"
      end

      Promenade.histogram :kafka_producer_delivery_attempts do
        doc "A count of the total message deliveries attempted"
        buckets [0, 6, 12, 18, 24, 30]
      end

      Promenade.histogram :kafka_producer_ack_latency do
        doc "Delay between message being produced and Acked"
        buckets :network
      end

      Promenade.gauge :kafka_async_producer_queue_size do
        doc "Size of Kafka async producer queue"
      end

      Promenade.gauge :kafka_async_producer_max_queue_size do
        doc "Max size of Kafka async producer queue"
      end

      Promenade.gauge :kafka_async_producer_queue_fill_ratio do
        doc "Size of Kafka async producer queue"
      end

      Promenade.counter :kafka_async_producer_dropped_messages do
        doc "Count of dropped messages"
      end

      def emitted(event)
        statistics = event.payload[:statistics].with_indifferent_access

        report_root_metrics(statistics)
        report_broker_metrics(statistics)
      end

      private

        def report_root_metrics(statistics)
          labels = get_labels(statistics)
          queue_size = statistics[:msg_cnt]
          max_queue_size = statistics[:msg_max]
          message_size = statistics[:msg_size]
          delivered_messages = statistics[:txmsgs]
          queue_fill_ratio = queue_size.to_f / max_queue_size.to_f

          Promenade.metric(:kafka_async_producer_queue_size).set(labels, queue_size)
          Rails.logger.info "[Statistics][Producer queue_size] #{queue_size}"
          Promenade.metric(:kafka_async_producer_max_queue_size).set(labels, max_queue_size)
          Rails.logger.info "[Statistics][Producer max_queue_size] #{max_queue_size}"
          Promenade.metric(:kafka_async_producer_queue_fill_ratio).set(labels, queue_fill_ratio)
          Rails.logger.info "[Statistics][Producer queue_fill_ratio] #{queue_fill_ratio}"
          Promenade.metric(:kafka_producer_message_size).observe(labels, message_size)
          Rails.logger.info "[Statistics][Producer message_size] #{message_size}"
          Promenade.metric(:kafka_producer_delivered_messages).increment(labels, delivered_messages)
          Rails.logger.info "[Statistics][karafka Producer Delivered Messages] #{delivered_messages}"
        end

        def report_broker_metrics(statistics)
          labels = get_labels(statistics)

          statistics[:brokers].map do |broker_name, broker_values|
            next if broker_values[:nodeid] == -1

            delivery_attempts = broker_values[:txretries]
            ack_latency = broker_values[:rtt][:avg]
            broker_labels = {
              broker_id: broker_name,
              topic: broker_values[:toppars].values[0][:topic]
            }

            Promenade.metric(:kafka_producer_delivery_attempts).observe(labels.merge(broker_labels), delivery_attempts)
            Promenade.metric(:kafka_producer_ack_latency).observe(labels, ack_latency)
            Rails.logger.info "[Statistics][Producer Broker ack_latency] #{ack_latency}"
            Rails.logger.info "[Statistics][Producer Broker Delivery Attempts] #{broker_name}: #{delivery_attempts}"
          end
        end

        def get_labels(statistics)
          labels = {
            client: statistics[:client_id],
          }
        end
    end
  end
end

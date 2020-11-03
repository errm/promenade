require "promenade/kafka/subscriber"

module Promenade
  module Kafka
    class ConsumerSubscriber < Subscriber
      attach_to "consumer.kafka"

      Promenade.gauge :kafka_consumer_time_lag do
        doc "Lag between message create and consume time"
      end

      Promenade.gauge :kafka_consumer_offset_lag do
        doc "Lag between message create and consume time"
      end

      Promenade.histogram :kafka_consumer_message_processing_latency do
        doc "Consumer message processing latency"
        buckets :network
      end

      Promenade.counter :kafka_consumer_messages_processed do
        doc "Messages processed by this consumer"
      end

      Promenade.counter :kafka_consumer_messages_fetched do
        doc "Messages fetched by this consumer"
      end

      Promenade.counter :kafka_consumer_message_processing_errors do
        doc "Consumer errors while processing a message"
      end

      Promenade.histogram :kafka_consumer_batch_processing_latency do
        doc "Consumer batch processing latency"
        buckets :network
      end

      Promenade.counter :kafka_consumer_batch_processing_errors do
        doc "Consumer errors while processing a batch"
      end

      Promenade.histogram :kafka_consumer_join_group do
        doc "Time taken to join"
        buckets :network
      end

      Promenade.counter :kafka_consumer_join_group_errors do
        doc "Errors joining the group"
      end

      Promenade.histogram :kafka_consumer_sync_group do
        doc "Time taken to sync"
        buckets :network
      end

      Promenade.counter :kafka_consumer_sync_group_errors do
        doc "Errors syncing the group"
      end

      Promenade.histogram :kafka_consumer_leave_group do
        doc "Time taken to leave group"
        buckets :network
      end

      Promenade.counter :kafka_consumer_leave_group_errors do
        doc "Errors leaving the group"
      end

      Promenade.histogram :kafka_consumer_pause_duration do
        doc "Time taken to leave group"
        buckets :network
      end

      def process_message(event) # rubocop:disable Metrics/AbcSize
        labels = get_labels(event)
        offset_lag = event.payload.fetch(:offset_lag)
        create_time = event.payload.fetch(:create_time)
        time_lag = create_time && ((Time.now.utc - create_time) * 1000).to_i

        if event.payload.key?(:exception)
          Promenade.metric(:kafka_consumer_message_processing_errors).increment(labels)
        else
          Promenade.metric(:kafka_consumer_messages_processed).increment(labels)
          Promenade.metric(:kafka_consumer_message_processing_latency).observe(labels, event.duration)
        end

        Promenade.metric(:kafka_consumer_ofset_lag).set(labels, offset_lag)

        # Not all messages have timestamps.
        Promenade.metric(:kafka_consumer_time_lag).set(labels, time_lag) if time_lag
      end

      def process_batch(event)
        labels = get_labels(event)
        offset_lag = event.payload.fetch(:offset_lag)
        messages = event.payload.fetch(:message_count)

        if event.payload.key?(:exception)
          Promenade.metric(:kafka_consumer_batch_processing_errors).increment(labels)
        else
          Promenade.metric(:kafka_consumer_messages_processed).increment(labels, messages)
          Promenade.metric(:kafka_consumer_batch_processing_latency).observe(labels, event.duration)
        end

        Promenade.metric(:kafka_consumer_ofset_lag).set(labels, offset_lag)
      end

      def fetch_batch(event)
        labels = get_labels(event)
        offset_lag = event.payload.fetch(:offset_lag)
        messages = event.payload.fetch(:message_count)

        Promenade.metric(:kafka_consumer_messages_fetched).increment(labels, messages)
        Promenade.metric(:kafka_consumer_ofset_lag).set(labels, offset_lag)
      end

      def join_group(event)
        labels = group_labels(event)
        Promenade.metric(:kafka_consumer_join_group).observe(labels, event.duration)
        Promenade.metric(:kafka_consumer_join_group_errors).increment(labels) if event.payload.key?(:exception)
      end

      def sync_group(event)
        labels = group_labels(event)
        Promenade.metric(:kafka_consumer_sync_group).observe(labels, event.duration)
        Promenade.metric(:kafka_consumer_sync_group_errors).increment(labels) if event.payload.key?(:exception)
      end

      def leave_group(event)
        labels = group_labels(event)
        Promenade.metric(:kafka_consumer_leave_group).observe(labels, event.duration)
        Promenade.metric(:kafka_consumer_leave_group_errors).increment(labels) if event.payload.key?(:exception)
      end

      def pause_status(event)
        Promenade.metric(:kafka_consumer_pause_duration).observe(get_labels(event), event.payload.fetch(:duration))
      end

      private

        def get_labels(event)
          {
            client: event.payload.fetch(:client_id),
            group: event.payload.fetch(:group_id),
            topic: event.payload.fetch(:topic),
            partition: event.payload.fetch(:partition),
          }
        end

        def group_labels(event)
          {
            client: event.payload.fetch(:client_id),
            group: event.payload.fetch(:group_id),
          }
        end
    end
  end
end

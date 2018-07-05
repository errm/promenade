require "promenade/kafka"

RSpec.describe Promenade::Kafka do
  include ::Promenade::Helper

  let(:backend) { ActiveSupport::Notifications }

  let(:client_id) { "test_client" }
  let(:topic) { "test_topic" }
  let(:labels) do
    {
      client: client_id,
      topic: topic,
    }
  end

  describe "producer.kafka" do
    describe "produce_message" do
      before do
        size = 128
        buffer_size = 20
        10.times do
          backend.instrument(
            "produce_message.producer.kafka",
            client_id: client_id,
            topic: topic,
            message_size: size,
            buffer_size: 10,
            max_buffer_size: 100,
          )
          size = size * 2
          buffer_size -= 1
        end
      end

      it "counts the messages" do
        expect(metric(:kafka_producer_messages).get(labels)).to eq 10
      end

      it "has a histogram of message size" do
        expect(metric(:kafka_producer_message_size).get(labels)).to eq(
          128 => 1.0,
          256 => 2.0,
          512 => 3.0,
          1024 => 4.0,
          2048 => 5.0,
          4096 => 6.0,
          8192 => 7.0,
          16384 => 8.0,
          32768 => 9.0,
          65536 => 10.0,
          131072 => 10.0,
        )
      end

      it "gauges buffer size and fill ratio" do
        expect(metric(:kafka_producer_buffer_size).get(client: client_id)).to eq 10
        expect(metric(:kafka_producer_max_buffer_size).get(client: client_id)).to eq 100
        expect(metric(:kafka_producer_buffer_fill_ratio).get(client: client_id)).to eq 0.1
      end
    end

    describe "buffer overflow" do
      before do
        5.times do
          backend.instrument(
            "buffer_overflow.producer.kafka",
            client_id: client_id,
            topic: topic,
          )
        end
      end

      it "counts the errors" do
        expect(metric(:kafka_producer_buffer_overflows).get(labels)).to eq 5
      end
    end

    describe "deliver_messages" do
      context "happy path" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.5)

          4.times do
            backend.instrument(
              "deliver_messages.producer.kafka",
              client_id: client_id,
              delivered_message_count: 10,
              attempts: 1,
            )
          end
        end

        it "there are no errors" do
          expect(metric(:kafka_producer_delivery_errors).get(client: client_id)).to eq 0
        end

        it "counts the delivered messages" do
          expect(metric(:kafka_producer_delivered_messages).get(client: client_id)).to eq 40
        end

        it "records the delivery latency" do
          expect(metric(:kafka_producer_delivery_latency).get(client: client_id)).to eq(
            0.005 => 0.0, 0.01 => 0.0, 0.025 => 0.0, 0.05 => 0.0, 0.1 => 0.0, 0.25 => 0.0, 0.5 => 4.0, 1 => 4.0, 2.5 => 4.0, 5 => 4.0, 10 => 4.0,
          )
        end
      end

      context "with errors" do
        before do
          4.times do
            backend.instrument(
              "deliver_messages.producer.kafka",
              client_id: client_id,
              delivered_message_count: 10,
              attempts: 1,
              exception: true,
            )
          end
        end

        it "counts the errors" do
          expect(metric(:kafka_producer_delivery_errors).get(client: client_id)).to eq 4
        end
      end
    end

    describe "ack_message" do
      before do
        [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].each do |delay|
          backend.instrument(
            "ack_message.producer.kafka",
            client_id: client_id,
            topic: topic,
            delay: delay,
          )
        end
      end

      it "counts the messages" do
        expect(metric(:kafka_producer_ack_messages).get(labels)).to eq 11
      end

      it "has a histogram of the delay" do
        expect(metric(:kafka_producer_ack_latency).get(labels)).to eq(
          0.005 => 1.0,
          0.01 => 2.0,
          0.025 => 3.0,
          0.05 => 4.0,
          0.1 => 5.0,
          0.25 => 6.0,
          0.5 => 7.0,
          1 => 8.0,
          2.5 => 9.0,
          5 => 10.0,
          10 => 11.0,
        )
      end
    end

    describe "topic errors" do
      before do
        5.times do
          backend.instrument(
            "topic_error.producer.kafka",
            client_id: "test_client",
            topic: "ackattack",
          )
        end
      end
      it "counts the errors" do
        expect(metric(:kafka_producer_ack_errors).get(client: "test_client", topic: "ackattack")).to eq 5
      end
    end
  end

  describe "async_producer.kafka" do
    describe "enqueue_message" do
      before do
        backend.instrument(
          "enqueue_message.async_producer.kafka",
          queue_size: 10,
          max_queue_size: 20,
          client_id: client_id,
          topic: topic,
        )
      end

      it "records the queue size and fill ratio" do
        expect(metric(:kafka_async_producer_queue_size).get(labels)).to eq 10
        expect(metric(:kafka_async_producer_max_queue_size).get(labels)).to eq 20
        expect(metric(:kafka_async_producer_queue_fill_ratio).get(labels)).to eq 0.5
      end
    end

    describe "buffer_overflow" do
      before do
        11.times do
          backend.instrument(
            "buffer_overflow.async_producer.kafka",
            client_id: client_id,
            topic: topic,
          )
        end
      end

      it "counts the errors" do
        expect(metric(:kafka_async_producer_buffer_overflows).get(labels)).to eq 11
      end
    end

    describe "drop_messages" do
      before do
        11.times do
          backend.instrument(
            "drop_messages.async_producer.kafka",
            client_id: client_id,
            message_count: 2,
          )
        end
      end

      it "counts the errors" do
        expect(metric(:kafka_async_producer_dropped_messages).get(client: client_id)).to eq 22
      end
    end
  end

  describe "connection" do
    let(:api) { "an_api" }
    let(:host) { "my-awesome-broker.aws.om" }
    let(:labels) { { client: client_id, api: api, broker: host } }

    describe "request" do
      context "happy path" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.5)

          size = 128
          11.times do
            backend.instrument(
              "request.connection.kafka",
              client_id: client_id,
              api: api,
              broker_host: host,
              request_size: size,
              response_size: size,
            )

            size *= 2
          end
        end

        it "counts the calls" do
          expect(metric(:kafka_connection_calls).get(labels)).to eq 11
        end

        it "mesures the connection latency" do
          expect(metric(:kafka_connection_latency).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 0.0,
            0.5 => 11.0,
            1 => 11.0,
            2.5 => 11.0,
            5 => 11.0,
            10 => 11.0,
          )
        end

        it "records the request and response size" do
          # TODO: summary metrics have count + sum, but I can't work out how to access the count
          expect(metric(:kafka_connection_response_size).get(labels)).to eq 262016
          expect(metric(:kafka_connection_response_size).get(labels)).to eq 262016
        end
      end
    end
  end

  describe "fetcher" do
    describe "loop" do
      before do
        backend.instrument(
          "loop.fetcher.kafka",
          client_id: client_id,
          group_id: "fetcher_group",
          queue_size: 17,
        )
      end

      it "gauges the queue size" do
        expect(metric(:kafka_fetcher_queue_size).get(client: client_id, group: "fetcher_group")).to eq 17
      end
    end
  end

  describe "consumer" do
    let(:labels) do
      { client: client_id, group: "test_group", topic: topic, partition: 6 }
    end

    describe "process_message" do
      describe "happy_path" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.5)
          backend.instrument(
            "process_message.consumer.kafka",
            client_id: client_id,
            group_id: "test_group",
            topic: topic,
            partition: 6,
            offset_lag: 5,
            create_time: (Time.now.utc - 5),
          )
        end

        it "exposes the time lag between processing and now" do
          expect(metric(:kafka_consumer_time_lag).get(labels)).to eq 5000
        end

        it "exposes the ofest lag" do
          expect(metric(:kafka_consumer_ofset_lag).get(labels)).to eq 5
        end

        it "records a histogram of consumer timing" do
          expect(metric(:kafka_consumer_message_processing_latency).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 0.0,
            0.5 => 1.0,
            1 => 1.0,
            2.5 => 1.0,
            5 => 1.0,
            10 => 1.0,
          )
        end

        it "counts the messages processed" do
          expect(metric(:kafka_consumer_messages_processed).get(labels)).to eq 1
        end
      end

      describe "errors" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.5)
          5.times do
            backend.instrument(
              "process_message.consumer.kafka",
              client_id: client_id,
              group_id: "test_group",
              topic: topic,
              partition: 6,
              offset_lag: 5,
              create_time: (Time.now.utc - 5),
              exception: "really broken",
            )
          end
        end

        it "counts errors" do
          expect(metric(:kafka_consumer_message_processing_errors).get(labels)).to eq 5
        end

        it "does not count processed metrics or record latency" do
          expect(metric(:kafka_consumer_messages_processed).get(labels)).to eq 0
          expect(metric(:kafka_consumer_message_processing_latency).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 0.0,
            0.5 => 0.0,
            1 => 0.0,
            2.5 => 0.0,
            5 => 0.0,
            10 => 0.0,
          )
        end

        it "does record other relevent metrics" do
          expect(metric(:kafka_consumer_time_lag).get(labels)).to eq 5000
          expect(metric(:kafka_consumer_ofset_lag).get(labels)).to eq 5
        end
      end

      describe "messages without timestamps" do
        before do
          backend.instrument(
            "process_message.consumer.kafka",
            client_id: client_id,
            group_id: "test_group",
            topic: topic,
            partition: 6,
            offset_lag: 5,
            create_time: Time.now.utc - 7,
          )

          backend.instrument(
            "process_message.consumer.kafka",
            client_id: client_id,
            group_id: "test_group",
            topic: topic,
            partition: 6,
            offset_lag: 5,
            create_time: nil,
          )
        end

        it "doesn't change the time lag" do
          expect(metric(:kafka_consumer_time_lag).get(labels)).to eq 7000
        end
      end
    end

    describe "process_batch" do
      describe "happy_path" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(1)
          backend.instrument(
            "process_batch.consumer.kafka",
            client_id: client_id,
            group_id: "test_group",
            topic: topic,
            partition: 6,
            offset_lag: 200,
            message_count: 100,
          )
        end

        it "counts the messages processed" do
          expect(metric(:kafka_consumer_messages_processed).get(labels)).to eq 100
        end

        it "has a histogram of batch latency" do
          expect(metric(:kafka_consumer_batch_processing_latency).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 0.0,
            0.5 => 0.0,
            1 => 1,
            2.5 => 1,
            5 => 1,
            10 => 1,
          )
        end

        it "records the ofset lag" do
          expect(metric(:kafka_consumer_ofset_lag).get(labels)).to eq 200
        end
      end

      describe "with an error" do
        before do
          backend.instrument(
            "process_batch.consumer.kafka",
            client_id: client_id,
            group_id: "test_group",
            topic: topic,
            partition: 6,
            offset_lag: 200,
            message_count: 100,
            exception: "Broken, really broken",
          )
        end

        it "counts the error" do
          expect(metric(:kafka_consumer_batch_processing_errors).get(labels)).to eq 1
        end
      end
    end

    describe "join_group" do
      let(:labels) do
        { client: client_id, group: "test_group" }
      end

      describe "happy_path" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.25)
          backend.instrument(
            "join_group.consumer.kafka",
            client_id: client_id,
            group_id: "test_group",
          )
        end

        it "records a histogram for the time taken" do
          expect(metric(:kafka_consumer_join_group).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 1,
            0.5 => 1,
            1 => 1,
            2.5 => 1,
            5 => 1,
            10 => 1,
          )
        end
      end

      describe "with error" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.25)

          5.times do
            backend.instrument(
              "join_group.consumer.kafka",
              client_id: client_id,
              group_id: "test_group",
              exception: "could not join the group",
            )
          end
        end

        it "records a histogram for the time taken" do
          expect(metric(:kafka_consumer_join_group).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 5,
            0.5 => 5,
            1 => 5,
            2.5 => 5,
            5 => 5,
            10 => 5,
          )
        end

        it "counts the error" do
          expect(metric(:kafka_consumer_join_group_errors).get(labels)).to eq 5
        end
      end
    end

    describe "sync_group" do
      let(:labels) do
        { client: client_id, group: "test_group" }
      end

      describe "happy_path" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.25)
          backend.instrument(
            "sync_group.consumer.kafka",
            client_id: client_id,
            group_id: "test_group",
          )
        end

        it "records a histogram for the time taken" do
          expect(metric(:kafka_consumer_sync_group).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 1,
            0.5 => 1,
            1 => 1,
            2.5 => 1,
            5 => 1,
            10 => 1,
          )
        end
      end

      describe "with error" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.25)

          3.times do
            backend.instrument(
              "sync_group.consumer.kafka",
              client_id: client_id,
              group_id: "test_group",
              exception: "could not sync the group",
            )
          end
        end

        it "records a histogram for the time taken" do
          expect(metric(:kafka_consumer_sync_group).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 3,
            0.5 => 3,
            1 => 3,
            2.5 => 3,
            5 => 3,
            10 => 3,
          )
        end

        it "counts the error" do
          expect(metric(:kafka_consumer_sync_group_errors).get(labels)).to eq 3
        end
      end
    end

    describe "leave_group" do
      let(:labels) do
        { client: client_id, group: "test_group" }
      end

      describe "happy_path" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.25)
          backend.instrument(
            "leave_group.consumer.kafka",
            client_id: client_id,
            group_id: "test_group",
          )
        end

        it "records a histogram for the time taken" do
          expect(metric(:kafka_consumer_leave_group).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 1,
            0.5 => 1,
            1 => 1,
            2.5 => 1,
            5 => 1,
            10 => 1,
          )
        end
      end

      describe "with error" do
        before do
          allow_any_instance_of(ActiveSupport::Notifications::Event).to receive(:duration).and_return(0.25)

          3.times do
            backend.instrument(
              "leave_group.consumer.kafka",
              client_id: client_id,
              group_id: "test_group",
              exception: "could not leave the group",
            )
          end
        end

        it "records a histogram for the time taken" do
          expect(metric(:kafka_consumer_leave_group).get(labels)).to eq(
            0.005 => 0.0,
            0.01 => 0.0,
            0.025 => 0.0,
            0.05 => 0.0,
            0.1 => 0.0,
            0.25 => 3,
            0.5 => 3,
            1 => 3,
            2.5 => 3,
            5 => 3,
            10 => 3,
          )
        end

        it "counts the error" do
          expect(metric(:kafka_consumer_leave_group_errors).get(labels)).to eq 3
        end
      end
    end

    describe "pause_status" do
      before do
        backend.instrument(
          "pause_status.consumer.kafka",
          client_id: client_id,
          group_id: "test_group",
          topic: topic,
          partition: 6,
          duration: 0.25,
        )
      end

      it "records the pause time" do
        expect(metric(:kafka_consumer_pause_duration).get(labels)).to eq(
          0.005 => 0.0,
          0.01 => 0.0,
          0.025 => 0.0,
          0.05 => 0.0,
          0.1 => 0.0,
          0.25 => 1,
          0.5 => 1,
          1 => 1,
          2.5 => 1,
          5 => 1,
          10 => 1,
        )
      end
    end
  end
end

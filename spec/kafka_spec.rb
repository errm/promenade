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

      it "has a historgram of message size" do
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
end

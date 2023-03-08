require "promenade/waterdrop"
require "active_support/notifications"
require "active_support/isolated_execution_state"

RSpec.describe Promenade::Waterdrop do
  let(:backend) { ActiveSupport::Notifications }
  let(:client_id) { "test_client" }
  let(:topic) { "topic_name" }

  describe "message.waterdrop" do
    let(:producer_id) { "producer_id" }

    let(:labels) do
      { client: producer_id, topic: topic }
    end

    let(:message) do
      { key: "message_key", topic: topic }
    end

    describe "produced_async" do
      before do
        backend.instrument(
          "produced_async.message.waterdrop",
          message: message,
          producer_id: producer_id,
        )
      end

      it "exposes the kafka_producer_messages" do
        expect(Promenade.metric(:waterdrop_producer_messages).get(labels)).to eq 1
      end
    end

    describe "produced_sync" do
      before do
        backend.instrument(
          "produced_sync.message.waterdrop",
          message: message,
          producer_id: producer_id,
        )
      end

      it "exposes the kafka_producer_messages" do
        expect(Promenade.metric(:waterdrop_producer_messages).get(labels)).to eq 1
      end
    end

    describe "acknowledged" do
      before do
        backend.instrument(
          "acknowledged.message.waterdrop",
          producer_id: producer_id,
        )
      end

      let(:labels) do
        { client: producer_id }
      end


      it "exposes the kafka_producer_ack_messages" do
        expect(Promenade.metric(:waterdrop_producer_ack_messages).get(labels)).to eq 1
      end
    end
  end

  describe "statistics.karafka" do
    let(:client_id) { "test_client" }
    let(:bootstraps_broker) { "bootstraps" }
    let(:labels) do
      { client: client_id }
    end
    let(:broker_name) { "localhost:9092/2" }

    before do
      size = 128
      ack_latency = 0.01
      attempts = 2

      10.times do
        backend.instrument(
          "emitted.statistics.waterdrop",
          statistics: {
            msg_cnt: 1,
            msg_max: 10,
            msg_size: size,
            txmsgs: 13,
            client_id: client_id,
            brokers: {
              broker_name => {
                nodeid: 3,
                txretries: attempts,
                rtt: {
                  avg: ack_latency,
                },
                toppars: {
                  topic => {
                    topic: topic,
                    partition: 1,
                  },
                },
              },
              bootstraps_broker => {
                nodeid: -1,
                rtt: {
                  avg: 0.5,
                },
                connects: 5,
              },
            },
          },
        )
        size = size * 2
        ack_latency = ack_latency * 2
        attempts = attempts * 2
      end
    end

    describe "exposes root metrics" do
      it "exposes the kafka_async_producer_queue_size" do
        expect(Promenade.metric(:waterdrop_async_producer_queue_size).get(labels)).to eq 1
      end

      it "exposes kafka_async_producer_max_queue_size" do
        expect(Promenade.metric(:waterdrop_async_producer_max_queue_size).get(labels)).to eq 10
      end

      it "exposes kafka_async_producer_max_queue_size" do
        expect(Promenade.metric(:waterdrop_async_producer_max_queue_size).get(labels)).to eq 10
      end

      it "exposes kafka_producer_message_size" do
        expect(Promenade.metric(:waterdrop_producer_message_size).get(labels)).to eq(
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

      it "exposes kafka_producer_delivered_messages" do
        expect(Promenade.metric(:waterdrop_producer_delivered_messages).get(labels)).to eq 130
      end
    end

    describe "delivery metrics" do
      let(:labels) do
        { client: client_id, broker_id: broker_name }
      end

      it "exposes kafka_producer_delivery_attempts" do
        expect(Promenade.metric(:waterdrop_producer_delivery_attempts).get(labels)).to eq(
          0 => 0,
          6 => 2,
          12 => 3,
          18 => 4,
          24 => 4,
          30 => 4,
        )
      end
    end

    describe "ack latency" do
      let(:labels) do
        { client: client_id }
      end

      it "exposes kafka_producer_delivery_attempts" do
        expect(Promenade.metric(:waterdrop_producer_ack_latency_seconds).get(labels)).to eq(
          0.005 => 10.0,
          0.01 => 10.0,
          0.025 => 10.0,
          0.05 => 10.0,
          0.1 => 10.0,
          0.25 => 10.0,
          0.5 => 10.0,
          1 => 10.0,
          2.5 => 10.0,
          5 => 10.0,
          10 => 10.0,
        )
      end
    end
  end

  describe "error.karafka" do
    let(:error_type) { "librdkafka.dispatch_error" }
    let(:labels) do
      { error_type: error_type }
    end

    before do
      backend.instrument(
        "occurred.error.waterdrop",
        type: error_type,
      )
    end

    it "exposes the karafka errors" do
      expect(Promenade.metric(:waterdrop_errors).get(labels)).to eq 1
    end
  end
end

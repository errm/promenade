require "promenade/waterdrop"
require "active_support/notifications"
require "active_support/isolated_execution_state"

RSpec.describe Promenade::Waterdrop do
  let(:backend) { ActiveSupport::Notifications }
  let(:client_id) { "test_client" }

  describe "message.waterdrop" do
    let(:producer_id) { "producer_id" }
    let(:topic) { "topic_name" }

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
        expect(Promenade.metric(:kafka_producer_messages).get(labels)).to eq 1
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
        expect(Promenade.metric(:kafka_producer_messages).get(labels)).to eq 1
      end
    end
  end

  describe "statistics.karafka" do
    let(:client_id) { "test_client" }
    let(:consumer_lag_stored) { 1 }
    let(:internal_partition) { "-1" }
    let(:bootstraps_broker) { "bootstraps" }
    let(:labels) do
      { client: client_id }
    end

    before do
      size = 128

      10.times do
        backend.instrument(
          "emitted.statistics.waterdrop",
          statistics: {
            msg_cnt: 1,
            msg_max: 10,
            msg_size: size,
            txmsgs: 13,
            client_id: client_id,
            brokers: {},
          },
        )
        size = size * 2
      end
    end

    describe "exposes root metrics" do
      it "exposes the kafka_async_producer_queue_size" do
        expect(Promenade.metric(:kafka_async_producer_queue_size).get(labels)).to eq 1
      end

      it "exposes kafka_async_producer_max_queue_size" do
        expect(Promenade.metric(:kafka_async_producer_max_queue_size).get(labels)).to eq 10
      end

      it "exposes kafka_async_producer_max_queue_size" do
        expect(Promenade.metric(:kafka_async_producer_max_queue_size).get(labels)).to eq 10
      end

      it "exposes kafka_producer_message_size" do
        expect(Promenade.metric(:kafka_producer_message_size).get(labels)).to eq(
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
        expect(Promenade.metric(:kafka_producer_delivered_messages).get(labels)).to eq 130
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

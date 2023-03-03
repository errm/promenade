require "promenade/karafka"
require "active_support/notifications"
require "active_support/isolated_execution_state"

RSpec.describe Promenade::Karafka do
  let(:client) { "test_client" }
  let(:topic_name) { "test_topic" }
  let(:consumer_group_id) { "consumer_group_id" }
  let(:partition) { "0" }
  let(:messages_size) { 8 }
  let(:time) { 1 }

  let(:backend) { ActiveSupport::Notifications }
  let(:metadata) { Struct.new(:partition, :topic).new(partition, topic_name) }
  let(:messages) { Struct.new(:size, :metadata).new(messages_size, metadata) }
  let(:topic) { Struct.new(:consumer_group, :kafka).new(Struct.new(:id).new(consumer_group_id), {:"client.id" => client }) }
  let(:consumer) { Struct.new(:messages, :topic).new(messages, topic) }


  let(:labels) do
    { client: client, group: consumer_group_id, topic: topic_name, partition: partition }
  end

  describe "consumer.karafka" do
    before do
      backend.instrument(
        "consumed.consumer.karafka",
        caller: consumer,
        time: time,
      )
    end

    it "counts the messages processed" do
      expect(Promenade.metric(:kafka_consumer_messages_processed).get(labels)).to eq 8
    end

    it "has a histogram of batch latency" do
      expect(Promenade.metric(:kafka_consumer_batch_processing_latency).get(labels)).to eq(
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
  end

  describe "statistics.karafka" do
    let(:statistics) do
      {
        topics: {
          topic_name: {
            partitions: {
              "0": {
                consumer_lag_stored: 1,
              },
            },
          },
        },
        brokers: {
          "localhost:9092/2": {
            nodeid: 3,
            rtt: {
              avg: 0.5,
            },
            connects: 5,
          },
        },
        client_id: "client_id",
      }
    end

    before do
      11.times do
        backend.instrument(
          "emitted.statistics.karafka",
          statistics: statistics,
        )
      end
    end

    describe "reports partition_metrics" do
      let(:labels) do
        { client: "client_id", topic: "topic_name", partition: "0" }
      end

      it "exposes the ofest lag" do
        expect(Promenade.metric(:kafka_consumer_ofset_lag).get(labels)).to eq 1
      end
    end

    describe "reports connection_metrics" do
      let(:labels) do
        { client: "client_id", api: "unknown", broker: "localhost:9092/2" }
      end

      it "exposes the kafka connection calls" do
        expect(Promenade.metric(:kafka_connection_calls).get(labels)).to eq 55
      end

      it "exposes the kafka connection latency" do
        expect(Promenade.metric(:kafka_connection_latency).get(labels)).to eq(
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
    end
  end

  describe "error.karafka" do
    let(:labels) do
      { error_type: "consumer.consume.error" }
    end

    before do
      backend.instrument(
        "occurred.error.karafka",
        type: "consumer.consume.error",
      )
    end

    it "exposes the karafka errors" do
      expect(Promenade.metric(:karafka_errors).get(labels)).to eq 1
    end
  end
end

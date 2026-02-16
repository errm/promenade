require "promenade/karafka"
require "active_support/notifications"
require "active_support/isolated_execution_state"

RSpec.describe Promenade::Karafka do
  let(:backend) { ActiveSupport::Notifications }
  let(:client_id) { "test_client" }
  let(:topic_name) { "topic_name" }
  let(:consumer_group_id) { "consumer_group_id" }
  let(:partition) { "0" }

  let(:labels) do
    { client: client_id, group: consumer_group_id, topic: topic_name, partition: partition }
  end

  describe "consumer.karafka" do
    let(:metadata) { Struct.new(:partition, :topic).new(partition, topic_name) } # rubocop:disable Lint/StructNewOverride
    let(:messages) { Struct.new(:size, :metadata).new(messages_size, metadata) } # rubocop:disable Lint/StructNewOverride
    let(:topic) { Struct.new(:consumer_group, :kafka).new(Struct.new(:id).new(consumer_group_id), { "client.id": client_id }) }
    let(:consumer) { Struct.new(:messages, :topic).new(messages, topic) }
    let(:messages_size) { 8 }
    let(:time) { 1000 }

    before do
      backend.instrument(
        "consumed.consumer.karafka",
        caller: consumer,
        time: time,
      )
    end

    it "counts the messages processed" do
      expect(Promenade.metric(:karafka_consumer_messages_processed).get(labels)).to eq messages_size
    end

    it "has a histogram of batch latency" do
      expect(Promenade.metric(:karafka_consumer_batch_processing_duration_seconds).get(labels)).to eq(
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
    let(:consumer_lag_stored) { 1 }
    let(:internal_partition) { "-1" }
    let(:bootstraps_broker) { "bootstraps" }

    let(:statistics) do
      {
        topics: {
          topic_name => {
            partitions: {
              partition => {
                consumer_lag_stored: consumer_lag_stored,
              },
            },
            internal_partition => {
              consumer_lag_stored: 10,
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
          bootstraps_broker => {
            nodeid: -1,
            rtt: {
              avg: 0.5,
            },
            connects: 5,
          },
        },
        client_id: client_id,
      }
    end

    before do
      11.times do
        backend.instrument(
          "emitted.statistics.karafka",
          consumer_group_id: consumer_group_id,
          statistics: statistics,
        )
      end
    end

    describe "reports partition_metrics" do
      let(:labels) do
        { client: client_id, topic: topic_name, partition: partition, group: consumer_group_id }
      end

      it "exposes the ofest lag" do
        expect(Promenade.metric(:karafka_consumer_offset_lag).get(labels)).to eq consumer_lag_stored
      end

      it "does not expose the ofest lag for internal partitions" do
        expect(Promenade.metric(:karafka_consumer_offset_lag).get(labels.merge(partition: internal_partition))).to eq 0
      end
    end

    describe "reports connection_metrics" do
      let(:labels) do
        { client: client_id, broker: "localhost:9092/2" }
      end

      it "exposes the kafka connection calls" do
        expect(Promenade.metric(:karafka_connection_calls).get(labels)).to eq 55
      end

      it "does not expose the connection_metrics for bootstrap broker" do
        expect(Promenade.metric(:karafka_connection_calls).get(labels.merge(broker: bootstraps_broker))).to eq 0
      end

      it "exposes the kafka connection latency" do
        expect(Promenade.metric(:karafka_connection_latency_seconds).get(labels)).to eq(
          0.005 => 11.0,
          0.01 => 11.0,
          0.025 => 11.0,
          0.05 => 11.0,
          0.1 => 11.0,
          0.25 => 11.0,
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

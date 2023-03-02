require "promenade/karafka"
require "active_support/notifications"
require "active_support/isolated_execution_state"

RSpec.describe Promenade::Karafka do
  let(:client_id) { "test_client" }
  let(:topic_name) { "test_topic" }
  let(:consumer_group_id) { "consumer_group_id" }
  let(:partition) { 6 }
  let(:messages_size) { 5 }
  let(:time) { 1 }

  let(:backend) { ActiveSupport::Notifications }
  let(:metadata) { Struct.new(:partition, :topic).new(partition, topic_name) }
  let(:messages) { Struct.new(:size, :metadata).new(messages_size, metadata) }
  let(:topic) { Struct.new(:consumer_group).new(Struct.new(:id).new(consumer_group_id)) }
  let(:consumer) { Struct.new(:messages, :topic).new(messages, topic) }


  let(:labels) do
    { group: consumer_group_id, topic: topic_name, partition: partition }
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
      expect(Promenade.metric(:kafka_consumer_messages_processed).get(labels)).to eq 6
    end

    it "counts the processing latency" do
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
end

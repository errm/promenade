require "spec_helper"
require "promenade/pitchfork/worker_pid_provider"

RSpec.describe Promenade::Pitchfork::WorkerPidProvider do
  describe ".fetch" do
    subject { described_class.fetch }

    context "when worker_id is defined" do
      let(:worker_id) { "worker_id" }

      before do
        allow(described_class).to receive(:worker_id).and_return(worker_id)
      end

      it { is_expected.to eq(worker_id) }
    end

    context "when worker_id is not defined" do
      before do
        allow(described_class).to receive(:worker_id).and_return(nil)
        allow(Process).to receive(:pid).and_return(123)
      end

      it { is_expected.to eq("process_id_123") }
    end
  end

  describe ".worker_id" do
    subject { described_class.send(:worker_id) }
    around(:example) do |ex|
      old_name = $PROGRAM_NAME
      $PROGRAM_NAME = program_name
      ex.run
      $PROGRAM_NAME = old_name
    end

    context "when program_name matches pitchfork worker" do
      let(:program_name) { "pitchfork (gen:0) worker[1] - requests: 13, waiting" }


      it { is_expected.to eq("pitchfork_1") }

      context "when program_name matches pitchfork worker" do
        let(:program_name) { "pitchfork worker[1]" }

        it { is_expected.to eq("pitchfork_1") }
      end

      context "when program_name doesn't match pitchfork worker" do
        let(:program_name) { "something else" }

        let(:worker) { double("Pitchfork::Worker", nr: 2) }

        before do
          stub_const("Pitchfork::Worker", Class.new)
          allow(ObjectSpace).to receive(:each_object).with(Pitchfork::Worker).and_return([worker])
        end

        it { is_expected.to eq("pitchfork_2") }
      end
    end
  end

  describe ".object_based_worker_id" do
    subject { described_class.send(:object_based_worker_id) }

    context "when Pitchfork::Worker is defined" do
      let(:worker) { double("Pitchfork::Worker", nr: 1) }

      before do
        stub_const("Pitchfork::Worker", Class.new)
        allow(ObjectSpace).to receive(:each_object).with(Pitchfork::Worker).and_return([worker])
      end

      it { is_expected.to eq(1) }
    end

    context "when Pitchfork::Worker is not defined" do
      it { is_expected.to be_nil }
    end
  end
end

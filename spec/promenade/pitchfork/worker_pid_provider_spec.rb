require "spec_helper"
require "promenade/pitchfork/worker_pid_provider"

RSpec.describe Promenade::Pitchfork::WorkerPidProvider do
  describe ".fetch" do
    before do
      allow(Process).to receive(:pid).and_return(123)
    end

    subject { described_class.fetch }

    context "fallback to pid when we cannot get the worker id" do
      it { is_expected.to eq("process_id_123") }
    end

    context "when there are pitchfork workers" do
      before do
        stub_const("Pitchfork::Worker", Class.new)
        allow(ObjectSpace).to receive(:each_object).with(Pitchfork::Worker).
          and_yield(double("Pitchfork::Worker", nr: 3, pid: 123)).
          and_yield(double("Pitchfork::Worker", nr: 3, pid: 123)).
          and_yield(double("Pitchfork::Worker", nr: 3, pid: 123))
      end

      it { is_expected.to eq("worker_id_3") }
    end

    context "pitchfork workers with mismatching pid" do
      before do
        stub_const("Pitchfork::Worker", Class.new)
        allow(ObjectSpace).to receive(:each_object).with(Pitchfork::Worker).
          and_yield(double("Pitchfork::Worker", nr: 3, pid: 122)).
          and_yield(double("Pitchfork::Worker", nr: 3, pid: 122)).
          and_yield(double("Pitchfork::Worker", nr: 3, pid: 122))
      end

      it { is_expected.to eq("process_id_123") }
    end

    context "unexpeced pitchfork worker object" do
      before do
        stub_const("Pitchfork::Worker", Class.new)
        allow(ObjectSpace).to receive(:each_object).with(Pitchfork::Worker).
          and_yield(nil)
      end

      it { is_expected.to eq("process_id_123") }
    end
  end
end

require "spec_helper"
require "promenade/pitchfork/stats"

RSpec.describe Promenade::Pitchfork::Stats do
  let(:pitchfork_info) { class_double("Pitchfork::Info") }
  let(:raindrops_stats) { instance_double("Promenade::Raindrops::Stats", active_workers: 6, queued_requests: 2) }

  before do
    stub_const("Pitchfork::Info", pitchfork_info)
    allow(pitchfork_info).to receive(:workers_count).and_return(10)
    allow(pitchfork_info).to receive(:live_workers_count).and_return(8)

    allow(Promenade::Raindrops::Stats).to receive(:new).and_return(raindrops_stats)
  end

  describe "#instrument" do
    let(:metric) { instance_double("Promenade::Metric") }

    before do
      allow(Promenade).to receive(:metric).and_return(metric)
      allow(metric).to receive(:set)
    end

    it "sets the metrics correctly" do
      stats = Promenade::Pitchfork::Stats.new

      expect(Promenade).to receive(:metric).with(:pitchfork_workers_count).and_return(metric)
      expect(Promenade).to receive(:metric).with(:pitchfork_live_workers_count).and_return(metric)
      expect(Promenade).to receive(:metric).with(:pitchfork_capacity).and_return(metric)
      expect(Promenade).to receive(:metric).with(:pitchfork_busy_percent).and_return(metric)

      expect(metric).to receive(:set).with({}, 10)
      expect(metric).to receive(:set).with({}, 8)
      expect(metric).to receive(:set).with({}, 2)
      expect(metric).to receive(:set).with({}, 75.0)

      stats.instrument
    end
  end

  describe ".instrument" do
    it "calls the instance method instrument" do
      stats_instance = instance_double("Promenade::Pitchfork::Stats")
      allow(Promenade::Pitchfork::Stats).to receive(:new).and_return(stats_instance)
      allow(stats_instance).to receive(:instrument)

      Promenade::Pitchfork::Stats.instrument

      expect(stats_instance).to have_received(:instrument)
    end
  end
end

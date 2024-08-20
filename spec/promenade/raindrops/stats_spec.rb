require "spec_helper"
require "promenade/raindrops/stats"

RSpec.describe Promenade::Raindrops::Stats do
  let(:listen_stats) { instance_double("Raindrops::Linux::ListenStats", active: 1, queued: 1) }
  let(:listener_address) { "127.0.0.1:#{ENV.fetch('PORT', 3000)}" }

  before do
    allow(Raindrops::Linux).to receive(:tcp_listener_stats).and_return({ listener_address => listen_stats })
  end

  describe "#instrument" do
    let(:metric) { instance_double("Promenade::Metric") }

    before do
      allow(Promenade).to receive(:metric).and_return(metric)
      allow(metric).to receive(:set)
    end

    it "sets the metrics correctly" do
      expect(Promenade).to receive(:metric).with(:rack_active_workers).and_return(metric)
      expect(Promenade).to receive(:metric).with(:rack_queued_requests).and_return(metric)

      expect(metric).to receive(:set).with({}, 1)
      expect(metric).to receive(:set).with({}, 1)

      described_class.instrument
    end
  end
end

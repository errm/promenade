require "spec_helper"
require "promenade/pitchfork/mem_stats"

RSpec.describe Promenade::Pitchfork::MemStats do
  let(:pitfork_mem_info) { class_double("Pitchfork::MemInfo") }

  before do
    stub_const("Pitchfork::MemInfo", pitfork_mem_info)
    allow(pitfork_mem_info).to receive(:new).and_return(pitfork_mem_info)
    allow(pitfork_mem_info).to receive(:rss).and_return(100)
    allow(pitfork_mem_info).to receive(:pss).and_return(50)
    allow(pitfork_mem_info).to receive(:shared_memory).and_return(50)
  end

  describe "#instrument" do
    let(:metric) { instance_double("Promenade::Metric") }

    before do
      allow(Promenade).to receive(:metric).and_return(metric)
      allow(metric).to receive(:set)
    end

    it "sets the metrics correctly" do
      stats = Promenade::Pitchfork::MemStats.new

      expect(Promenade).to receive(:metric).with(:pitchfork_memory_usage_bytes).and_return(metric)

      expect(metric).to receive(:set).with({ type: "RSS" }, 102400)
      expect(metric).to receive(:set).with({ type: "PSS" }, 51200)
      expect(metric).to receive(:set).with({ type: "Shared" }, 51200)

      stats.instrument
    end
  end
end

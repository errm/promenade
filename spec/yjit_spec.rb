require "promenade/yjit/stats"

RSpec.describe Promenade::YJIT::Stats do
  describe "recording yjit stats" do
    it "records code_region_size" do
      if defined? RubyVM::YJIT
        described_class.instrument

        expect(Promenade.metric(:ruby_yjit_code_region_size).get).to eq RubyVM::YJIT.runtime_stats[:code_region_size]
      end
    end
  end
end

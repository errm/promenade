require "promenade/yjit/stats"

RSpec.describe Promenade::YJIT::Stats do
  describe "recording yjit stats" do
    it "records code_region_size" do
      if defined? RubyVM::YJIT

        # We want to test that this doesn't blow up when yjit isn't enabled
        # you need to run the testsuite with yjit disabled for this to work
        expect(RubyVM::YJIT.enabled?).to be_falsey
        expect { described_class.instrument }.not_to raise_error

        # Then we enable yjit to test the instrumentation
        RubyVM::YJIT.enable
        described_class.instrument

        expect(Promenade.metric(:ruby_yjit_code_region_size).get).to eq RubyVM::YJIT.runtime_stats[:code_region_size]
      end
    end
  end
end

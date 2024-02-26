require "promenade/yjit/stats"

RSpec.describe Promenade::YJIT::Stats do
  describe "recording yjit stats" do
    it "records code_region_size" do
      # This method should not blow up in any case
      expect { described_class.instrument }.not_to raise_error

      if defined?(RubyVM::YJIT) && defined?(RubyVM::YJIT.enable)

        # We want to test that this doesn't blow up when yjit is present but isn't enabled yet
        # you need to run the testsuite with yjit disabled for this to work
        expect(RubyVM::YJIT.enabled?).to be_falsey
        expect { described_class.instrument }.not_to raise_error

        # Then we enable yjit to test the instrumentation
        RubyVM::YJIT.enable
        described_class.instrument

        expect(Promenade.metric(:ruby_yjit_code_region_size).get).to eq RubyVM::YJIT.runtime_stats[:code_region_size]
      else
        version = RUBY_VERSION.match(/(\d).(\d).\d/)
        major = version[1].to_i
        minor = version[2].to_i
        if major >= 3 && minor >= 3
          flunk "YJIT must be avalibe to test properly in ruby 3.3+"
        end
      end
    end
  end
end

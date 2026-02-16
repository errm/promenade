require "promenade/yjit/stats"
require "promenade/yjit/middleware"
require "open3"

RSpec.describe Promenade::YJIT::Stats do
  describe "recording yjit stats" do
    it "doesn't explode" do
      # This method should not blow up in any case, on any version of ruby
      expect { described_class.instrument }.not_to raise_error

      metrics = run_yjit_metrics
      expect(metrics).to be_empty
    end

    it "records yjit stats" do
      version = RUBY_VERSION.match(/(\d).(\d).\d/)
      major = version[1].to_i
      minor = version[2].to_i

      unless major > 3 || major == 3 && minor >= 3
        pending "YJIT metrics are only expected to work in ruby 3.3.0+"
      end

      RubyVM::YJIT.enable
      described_class.instrument

      expect(Prometheus::Client.registry.get(:ruby_yjit_code_region_size).values[{}].get).to satisfy("be nonzero") { |n| n > 0 }

      # These intergration tests are run in another process so we can have greater control
      # over enabling yjit.
      metrics = run_yjit_metrics
      # we don't expect these metrics to have a value when yjit isn't enabled
      expect(metrics[:ruby_yjit_code_region_size]).to be_nil
      expect(metrics[:ruby_yjit_ratio_in_yjit]).to be_nil

      metrics = run_yjit_metrics("--yjit")
      expect(metrics[:ruby_yjit_code_region_size]).to satisfy("be nonzero") { |n| n > 0 }
      # ratio_in_yjit is only set when --yjit-stats is enabled
      expect(metrics[:ruby_yjit_ratio_in_yjit]).to be_nil

      if major == 3
        # ruby_yjit_ratio_in_yjit is only set when --yjit-stats is enabled but
        # is not supported in default builds of ruby 4.0.0+
        metrics = run_yjit_metrics("--yjit --yjit-stats=quiet")
        expect(metrics[:ruby_yjit_code_region_size]).to satisfy("be nonzero") { |n| n > 0 }
        expect(metrics[:ruby_yjit_ratio_in_yjit]).to satisfy("be nonzero") { |n| n > 0 }
      end
    end
  end

  def run_yjit_metrics(rubyopt = "")
    dir = Dir.mktmpdir
    begin
      output, status = Open3.capture2e({ "PROMETHEUS_MULTIPROC_DIR" => dir, "RUBYOPT" => rubyopt }, "bin/yjit_intergration_test")
      expect(status).to eq 0
      parse_metrics(output)
    ensure
      FileUtils.remove_entry dir
    end
  end

  def parse_metrics(output)
    output.lines.reject { |line| line.match("#") }.filter_map do |line|
      match = line.match(/([a-z_]+)\{.+\} (\d+\.?\d*)/)
      next unless match

      [match[1].to_sym, parse_number(match[2])]
    end.to_h
  end

  def parse_number(string)
    Integer(string)
  rescue StandardError
    string.to_f
  end
end

RSpec.describe Promenade::YJIT::Middlware do
  let(:app) { double(:app, call: nil) }

  it "is adds it's instrumentation method to the rack.after_reply array" do
    stats = class_spy("Promenade::YJIT::Stats").as_stubbed_const

    after_reply = []
    described_class.new(app).call({ "rack.after_reply" => after_reply })
    after_reply.each(&:call)

    expect(stats).to have_received(:instrument)
  end
end

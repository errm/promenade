require "promenade/yjit/stats"
require "open3"

RSpec.describe Promenade::YJIT::Stats do
  describe "recording yjit stats" do
    it "doesn't explode" do
      # This method should not blow up in any case
      expect { described_class.instrument }.not_to raise_error
    end

    it "records yjit stats" do
      version = RUBY_VERSION.match(/(\d).(\d).\d/)
      major = version[1].to_i
      minor = version[2].to_i
      unless major >= 3 && minor >= 3
        pending "YJIT metrics are only expected to work in ruby 3.3.0+"
      end

      metrics = run_yjit_metrics("")
      expect(metrics).to be_empty

      metrics = run_yjit_metrics("--yjit")
      expect(metrics[:ruby_yjit_code_region_size]).to satisfy("be nonzero") { |n| n > 0 }
      # ratio_in_yjit is only set when --yjit-stats is enabled
      expect(metrics[:ruby_yjit_ratio_in_yjit]).to be_nil

      metrics = run_yjit_metrics("--yjit --yjit-stats=quiet")
      expect(metrics[:ruby_yjit_code_region_size]).to satisfy("be nonzero") { |n| n > 0 }
      expect(metrics[:ruby_yjit_ratio_in_yjit]).to satisfy("be nonzero") { |n| n > 0 }
    end
  end

  def run_yjit_metrics(rubyopt)
    dir = Dir.mktmpdir
    begin
      output, status = Open3.capture2e({"PROMETHEUS_MULTIPROC_DIR" => dir, "RUBYOPT" => rubyopt}, "bin/yjit_intergration_test")
      expect(status).to eq 0
      parse_metrics(output)
    ensure
      FileUtils.remove_entry dir
    end
  end

  def parse_metrics(output)
    Hash[
      output.lines.reject { |line| line.match("#") }.map do |line|
        match = line.match(/([a-z_]+)\{.+\} (\d+\.?\d*)/)
        next unless match
        [match[1].to_sym, parse_number(match[2])]
      end.compact
    ]
  end

  def parse_number(string)
    Integer(string)
  rescue
    string.to_f
  end
end

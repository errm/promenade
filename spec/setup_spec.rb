require "tmpdir"

RSpec.describe Promenade do
  describe ".setup" do
    context "without rails" do
      context "environment variable set" do
        let(:multiproc_root) { Pathname.new(Dir.mktmpdir) }
        let(:multiproc_dir) { multiproc_root.join("app_name") }

        around do |example|
          ClimateControl.modify(PROMETHEUS_MULTIPROC_DIR: multiproc_dir.to_s) do
            Promenade.setup
            example.run
          end
          FileUtils.rm_rf multiproc_root
        end

        it "creates the configured directory" do
          expect(File.directory?(multiproc_dir)).to be_truthy
        end

        it "configures the prometheus client" do
          expect(::Prometheus::Client.configuration.multiprocess_files_dir.to_s).to eq multiproc_dir.to_s
        end
      end

      context "without environment set" do
        let(:pwd_root) { Pathname.new(Dir.mktmpdir) }
        let(:pwd_dir) { pwd_root.join("tmp", "promenade").realpath }

        before do
          Dir.chdir(pwd_root) do
            allow(Promenade).to receive(:rails_defined?).and_return(false)
            Promenade.setup
          end
        end

        after do
          FileUtils.rm_rf pwd_root
        end

        it "creates a directory under tmp for prometheus state files" do
          expect(File.directory?(pwd_dir)).to be_truthy
        end

        it "configures the prometheus client" do
          expect(::Prometheus::Client.configuration.multiprocess_files_dir).to eq pwd_dir
        end
      end
    end

    context "when Rails.root exists" do
      let(:rails_root) { Pathname.new(Dir.mktmpdir) }
      let(:rails_dir) { rails_root.join("tmp", "promenade") }

      before do
        rails = double(:rails, root: rails_root)
        stub_const("Rails", rails)
        Promenade.setup
      end

      after do
        FileUtils.rm_rf rails_root
      end

      it "creates a directory under tmp for prometheus state files" do
        expect(File.directory?(rails_dir)).to be_truthy
      end

      it "configures the prometheus client" do
        expect(::Prometheus::Client.configuration.multiprocess_files_dir.to_s).to eq rails_dir.to_s
      end

      context "environment variable set" do
        let(:multiproc_root) { Pathname.new(Dir.mktmpdir) }
        let(:multiproc_dir) { multiproc_root.join("app_name") }

        around do |example|
          ClimateControl.modify(PROMETHEUS_MULTIPROC_DIR: multiproc_dir.to_s) do
            Promenade.setup
            example.run
          end
          FileUtils.rm_rf multiproc_root
        end

        it "creates the configured directory" do
          expect(File.directory?(multiproc_dir)).to be_truthy
        end

        it "configures the prometheus client" do
          expect(::Prometheus::Client.configuration.multiprocess_files_dir.to_s).to eq multiproc_dir.to_s
        end
      end
    end
  end
end

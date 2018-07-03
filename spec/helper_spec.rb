require "promenade/helper"

RSpec.describe Promenade::Helper do
  let(:klass) do
    Class.new do
      include Promenade::Helper
    end
  end

  subject { klass.new }

  before(:each) do
    Promenade::Prometheus.reset!
  end

  describe "defining and using a counter" do
    describe "defaults" do
      before do
        klass.counter :promenade_testing_counter do
          doc "a docstring"
        end
      end

      it "can be incremented" do
        subject.metric(:promenade_testing_counter).increment
        expect(subject.metric(:promenade_testing_counter).get).to eq 1

        10.times { subject.metric(:promenade_testing_counter).increment}
        expect(subject.metric(:promenade_testing_counter).get).to eq 11

        subject.metric(:promenade_testing_counter).increment({}, 9)
        expect(subject.metric(:promenade_testing_counter).get).to eq 20
      end

      it "accepts labels" do
        subject.metric(:promenade_testing_counter).increment({ nice: "label" }, 3)
        expect(subject.metric(:promenade_testing_counter).get(nice: "label")).to eq 3
      end

      it "can be incremented from the class" do
        klass.metric(:promenade_testing_counter).increment

        expect(subject.metric(:promenade_testing_counter).get).to eq 1
      end

      it "throws an error when trying to redefine a counter" do
        expect do
          klass.counter :promenade_testing_counter
        end.to raise_error "Metric: promenade_testing_counter, is allready defined"
      end

      it "throws an error when trying a metric that isn't defined" do
        expect { subject.metric(:not_a_counter) }.to raise_error "No metric defined for: not_a_counter, you must define a metric before using it"
      end
    end

    describe "setting some options" do
      before do
        klass.counter :promenade_testing_counter do
          doc "a docstring"
          base_labels foo: "bar"
        end
      end

      it "uses the base_labels" do
        subject.metric(:promenade_testing_counter).increment
        expect(subject.metric(:promenade_testing_counter).get(foo: "bar")).to eq 1
      end

      it "accepts other labels" do
        subject.metric(:promenade_testing_counter).increment
        subject.metric(:promenade_testing_counter).increment({ foo: "baz" }, 7)

        expect(subject.metric(:promenade_testing_counter).get).to eq 1
        expect(subject.metric(:promenade_testing_counter).get(foo: "baz")).to eq 7
      end
    end
  end

  describe "defining and using a gauge" do
    context "defaults" do
      before do
        klass.gauge :promenade_testing_gauge do
          doc "This is a gauge to use in the tests"
        end
      end

      it "can be set" do
        subject.metric(:promenade_testing_gauge).set({}, 7)
        expect(subject.metric(:promenade_testing_gauge).get).to eq 7

        subject.metric(:promenade_testing_gauge).set({}, 11)
        expect(subject.metric(:promenade_testing_gauge).get).to eq 11
      end

      it "can be set from the class" do
        klass.metric(:promenade_testing_gauge).set({}, 21)
        expect(subject.metric(:promenade_testing_gauge).get).to eq 21
      end

      it "throws an error when trying to redefine a gauge" do
        expect do
          klass.gauge :promenade_testing_gauge
        end.to raise_error "Metric: promenade_testing_gauge, is allready defined"
      end

      it "has a multiprocess mode of all" do
        expect(subject.metric(:promenade_testing_gauge).instance_variable_get(:@multiprocess_mode)).to eq :all
      end
    end

    context "setting some options" do
      before do
        klass.gauge :promenade_testing_gauge do
          doc "some other docstring"
          multiprocess_mode :liveall
          base_labels base: "isbelongtous"
        end
      end

      it "sets the multiprocess mode" do
        expect(subject.metric(:promenade_testing_gauge).instance_variable_get(:@multiprocess_mode)).to eq :liveall
      end

      it "sets the base_labels" do
        expect(subject.metric(:promenade_testing_gauge).base_labels).to eq(base: "isbelongtous")
      end

      it "sets the docstring" do
        expect(subject.metric(:promenade_testing_gauge).docstring).to eq "some other docstring"
      end
    end
  end

  describe "defining and using a summary" do
    context "defaults" do
      before do
        klass.summary :promenade_testing_summary do
          doc "This is a summary to use in the tests"
        end
      end

      it "can observe" do
        subject.metric(:promenade_testing_summary).observe({}, 7)
        expect(subject.metric(:promenade_testing_summary).get).to eq 7.0

        subject.metric(:promenade_testing_summary).observe({}, 11)
        expect(subject.metric(:promenade_testing_summary).get).to eq 18.0
      end

      it "can observe from the class" do
        klass.metric(:promenade_testing_summary).observe({}, 21)
        expect(subject.metric(:promenade_testing_summary).get).to eq 21
      end

      it "throws an error when trying to redefine a summary" do
        expect do
          klass.gauge :promenade_testing_summary
        end.to raise_error "Metric: promenade_testing_summary, is allready defined"
      end
    end

    context "setting some options" do
      before do
        klass.summary :promenade_testing_summary do
          doc "some other docstring"
          base_labels all_your_base: "isbelongtous"
        end
      end

      it "sets the base_labels" do
        expect(subject.metric(:promenade_testing_summary).base_labels).to eq(all_your_base: "isbelongtous")
      end

      it "sets the docstring" do
        expect(subject.metric(:promenade_testing_summary).docstring).to eq "some other docstring"
      end
    end
  end

  describe "defining and using a histogram" do
    context "defaults" do
      before do
        klass.histogram :promenade_testing_histogram do
          doc "This is a histogram to use in the tests"
        end
      end

      it "can observe" do
        subject.metric(:promenade_testing_histogram).observe({}, 0.5)
        expect(subject.metric(:promenade_testing_histogram).get).to eq(
          0.005=>0.0,
          0.01=>0.0,
          0.025=>0.0,
          0.05=>0.0,
          0.1=>0.0,
          0.25=>0.0,
          0.5=>1.0,
          1=>1.0,
          2.5=>1.0,
          5=>1.0,
          10=>1.0
        )
      end
    end

    context "custom buckets" do
      before do
        klass.histogram :promenade_testing_histogram do
          doc "This is a histogram to use in the tests"
          buckets [0.25, 0.5, 1.0]
        end
      end

      it "can observe" do
        subject.metric(:promenade_testing_histogram).observe({}, 0.5)
        expect(subject.metric(:promenade_testing_histogram).get).to eq(
          0.25=>0.0,
          0.5=>1.0,
          1.0=>1.0,
        )
      end
    end

    context "bucket preset" do
      before do
        klass.histogram :promenade_testing_histogram do
          doc "This is a histogram to use in the tests"
          buckets :network
        end
      end

      it "can observe" do
        subject.metric(:promenade_testing_histogram).observe({}, 0.5)
        expect(subject.metric(:promenade_testing_histogram).get).to eq(
          0.005=>0.0,
          0.01=>0.0,
          0.025=>0.0,
          0.05=>0.0,
          0.1=>0.0,
          0.25=>0.0,
          0.5=>1.0,
          1=>1.0,
          2.5=>1.0,
          5=>1.0,
          10=>1.0
        )
      end
    end

    context "invalid bucket preset" do
      it "throws an error" do
        expect do
          klass.histogram :promenade_testing_oven_temperature do
            doc "Temperature of the oven in degrees science (Celsius)"
            buckets :gas_oven
          end
        end.to raise_error "gas_oven is not a valid bucket preset"
      end
    end
  end
end

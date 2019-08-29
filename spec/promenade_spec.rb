RSpec.describe Promenade do
  it "has a version number" do
    expect(Promenade::VERSION).not_to be nil
  end

  describe "defining and using a counter" do
    describe "defaults" do
      before do
        described_class.counter :promenade_testing_counter do
          doc "a docstring"
          labels [:nice]
          preset_labels nice: "tidy"
        end
      end

      it "can be incremented" do
        described_class.metric(:promenade_testing_counter).increment
        expect(described_class.metric(:promenade_testing_counter).get).to eq 1

        10.times { described_class.metric(:promenade_testing_counter).increment }
        expect(described_class.metric(:promenade_testing_counter).get).to eq 11

        described_class.metric(:promenade_testing_counter).increment(by: 9)
        expect(described_class.metric(:promenade_testing_counter).get).to eq 20
      end

      it "accepts labels" do
        described_class.metric(:promenade_testing_counter).increment(by: 3, labels: { nice: "label" })
        expect(described_class.metric(:promenade_testing_counter).get(labels: { nice: "label" })).to eq 3
      end

      it "uses the preset labels when not provided" do
        described_class.metric(:promenade_testing_counter).increment(by: 6, labels: { nice: "label" })
        described_class.metric(:promenade_testing_counter).increment(by: 3)
        expect(described_class.metric(:promenade_testing_counter).get(labels: { nice: "tidy" })).to eq 3
      end

      it "doesn't throw an error when trying to redefine a counter" do
        expect do
          described_class.counter :promenade_testing_counter
        end.to_not raise_error
      end

      it "throws an error when trying a metric that isn't defined" do
        expect { described_class.metric(:not_a_counter) }.to raise_error "No metric defined for: not_a_counter, you must define a metric before using it"
      end
    end

    describe "setting some options" do
      before do
        described_class.counter :promenade_testing_counter do
          doc "a docstring"
          labels [:foo]
          preset_labels foo: "bar"
        end
      end

      it "uses the preset_labels" do
        described_class.metric(:promenade_testing_counter).increment
        expect(described_class.metric(:promenade_testing_counter).get(labels: { foo: "bar" })).to eq 1
      end
    end
  end

  describe "defining and using a gauge" do
    context "defaults" do
      before do
        described_class.gauge :promenade_testing_gauge do
          doc "This is a gauge to use in the tests"
        end
      end

      it "can be set" do
        described_class.metric(:promenade_testing_gauge).set(7)
        expect(described_class.metric(:promenade_testing_gauge).get).to eq 7

        described_class.metric(:promenade_testing_gauge).set(11)
        expect(described_class.metric(:promenade_testing_gauge).get).to eq 11
      end

      it "does not throw an error when trying to redefine a gauge" do
        expect do
          described_class.gauge :promenade_testing_gauge
        end.to_not raise_error
      end
    end
  end

  describe "defining and using a summary" do
    context "defaults" do
      before do
        described_class.summary :promenade_testing_summary do
          doc "This is a summary to use in the tests"
        end
      end

      it "can observe" do
        described_class.metric(:promenade_testing_summary).observe(7)
        expect(described_class.metric(:promenade_testing_summary).get).to eq("count" => 1.0, "sum" => 7.0)

        described_class.metric(:promenade_testing_summary).observe(11)
        expect(described_class.metric(:promenade_testing_summary).get).to eq("count" => 2.0, "sum" => 18.0)
      end

      it "does not throw an error when trying to redefine a summary" do
        expect do
          described_class.gauge :promenade_testing_summary
        end.to_not raise_error
      end
    end

    context "setting some options" do
      before do
        described_class.summary :promenade_testing_summary do
          doc "some other docstring"
          labels [:all_your_base]
          preset_labels all_your_base: "isbelongtous"
        end
      end

      it "sets the preset_labels" do
        subject.metric(:promenade_testing_summary).observe(7)
        expect(subject.metric(:promenade_testing_summary).get(labels: { all_your_base: "isbelongtous" })).to eq("count" => 1.0, "sum" => 7.0)
      end

      it "sets the docstring" do
        expect(described_class.metric(:promenade_testing_summary).docstring).to eq "some other docstring"
      end
    end
  end

  describe "defining and using a histogram" do
    context "defaults" do
      before do
        described_class.histogram :promenade_testing_histogram do
          doc "This is a histogram to use in the tests"
        end
      end

      it "can observe" do
        described_class.metric(:promenade_testing_histogram).observe(0.5)
        expect(described_class.metric(:promenade_testing_histogram).get).to eq(
          "0.005" => 0.0,
          "0.01" => 0.0,
          "0.025" => 0.0,
          "0.05" => 0.0,
          "0.1" => 0.0,
          "0.25" => 0.0,
          "0.5" => 0.0,
          "1" => 1.0,
          "2.5" => 1.0,
          "5" => 1.0,
          "10" => 1.0,
          "+Inf" => 1.0,
          "sum" => 0.5,
        )
      end
    end

    context "custom buckets" do
      before do
        described_class.histogram :promenade_testing_histogram do
          doc "This is a histogram to use in the tests"
          buckets [0.25, 0.5, 1.0]
        end
      end

      it "can observe" do
        described_class.metric(:promenade_testing_histogram).observe(0.5)
        expect(described_class.metric(:promenade_testing_histogram).get).to eq(
          "0.25" => 0.0,
          "0.5" => 0.0,
          "1.0" => 1.0,
          "+Inf" => 1.0,
          "sum" => 0.5,
        )
      end
    end

    context "bucket preset" do
      before do
        described_class.histogram :promenade_testing_histogram do
          doc "This is a histogram to use in the tests"
          buckets :network
        end
      end

      it "can observe" do
        described_class.metric(:promenade_testing_histogram).observe(0.5)
        expect(described_class.metric(:promenade_testing_histogram).get).to eq(
          "0.005" => 0.0,
          "0.01" => 0.0,
          "0.025" => 0.0,
          "0.05" => 0.0,
          "0.1" => 0.0,
          "0.25" => 0.0,
          "0.5" => 0.0,
          "1" => 1.0,
          "2.5" => 1.0,
          "5" => 1.0,
          "10" => 1.0,
          "+Inf" => 1.0,
          "sum" => 0.5,
        )
      end
    end

    context "invalid bucket preset" do
      it "throws an error" do
        expect do
          described_class.histogram :promenade_testing_oven_temperature do
            doc "Temperature of the oven in degrees science (Celsius)"
            buckets :gas_oven
          end
        end.to raise_error "gas_oven is not a valid bucket preset"
      end
    end
  end
end

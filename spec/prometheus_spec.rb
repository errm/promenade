require "promenade/prometheus"

RSpec.describe Promenade::Prometheus::Options do
  before do
    subject.doc "Awesome level"
    subject.multiprocess_mode :liveall
    subject.base_labels awesome: "muchly"
    subject.buckets [1, 2, 3]
  end

  context "gauge" do
    it "returns the correct args" do
      expect(subject.args(:gauge)).to eq ["Awesome level", { awesome: "muchly" }, :liveall]
    end
  end

  context "histogram" do
    it "returns the correct args" do
      expect(subject.args(:histogram)).to eq ["Awesome level", { awesome: "muchly" }, [1, 2, 3]]
    end
  end

  context "counter" do
    it "returns the correct args" do
      expect(subject.args(:counter)).to eq ["Awesome level", { awesome: "muchly" }]
    end
  end

  context "summary" do
    it "returns the correct args" do
      expect(subject.args(:summary)).to eq ["Awesome level", { awesome: "muchly" }]
    end
  end

  context "unknown metric type" do
    it "throws an error" do
      expect { subject.args(:steam_gauge) }.to raise_error "Unsupported metric type: steam_gauge"
    end
  end
end

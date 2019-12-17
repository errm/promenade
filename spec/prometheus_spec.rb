require "promenade/prometheus"

RSpec.describe Promenade::Prometheus::DSL do
  before do
    subject.doc "Awesome level"
    subject.labels %i(awesome foo)
    subject.preset_labels awesome: "muchly"
    subject.buckets [1, 2, 3]
  end
  subject { described_class.new(type, :promenade_testing_metric) }
  let(:metric) { subject.metric }

  context "gauge" do
    let(:type) { :gauge }

    it "returns the correct metric" do
      expect(metric).to be_a Prometheus::Client::Gauge
      expect(metric.docstring).to eq "Awesome level"
      expect(metric.preset_labels).to eq(awesome: "muchly")
    end
  end

  context "histogram" do
    let(:type) { :histogram }

    it "returns the correct metric" do
      expect(metric).to be_a Prometheus::Client::Histogram
      expect(metric.docstring).to eq "Awesome level"
      expect(metric.preset_labels).to eq(awesome: "muchly")
      expect(metric.buckets).to eq [1, 2, 3]
    end
  end

  context "counter" do
    let(:type) { :counter }

    it "returns the correct metric" do
      expect(metric).to be_a Prometheus::Client::Counter
      expect(metric.docstring).to eq "Awesome level"
      expect(metric.preset_labels).to eq(awesome: "muchly")
    end
  end

  context "summary" do
    let(:type) { :summary }

    it "returns the correct metric" do
      expect(metric).to be_a Prometheus::Client::Summary
      expect(metric.docstring).to eq "Awesome level"
      expect(metric.preset_labels).to eq(awesome: "muchly")
    end
  end

  context "unknown metric type" do
    let(:type) { :steam_gauge }

    it "throws an error" do
      expect { metric }.to raise_error "Unsupported metric type: steam_gauge"
    end
  end
end

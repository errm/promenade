require "promenade/raindrops/middleware"

RSpec.describe Promenade::Raindrops::Middleware do
  let(:app) { double(:app, call: nil) }
  let(:listener_address) { "127.0.0.1:#{ENV.fetch('PORT', 3000)}" }

  shared_examples "middleware" do
    it "is add it's instrumentaion to the rack.after_reply" do
      stats = class_spy("Promenade::Raindrops::Stats").as_stubbed_const

      after_reply = []
      described_class.new(app).call({ "rack.after_reply" => after_reply })
      after_reply.each(&:call)

      expect(stats).to have_received(:instrument).with(listener_address: listener_address)
    end
  end

  context "when Pitchfork is defined" do
    let(:pitchfork) { class_double("Pitchfork").as_stubbed_const }

    before do
      allow(pitchfork).to receive(:listener_names).and_return([listener_address])
    end

    it_behaves_like "middleware"
  end

  context "when Unicorn is defined" do
    let(:unicorn) { class_double("Unicorn").as_stubbed_const }

    before do
      allow(unicorn).to receive(:listener_names).and_return([listener_address])
    end

    it_behaves_like "middleware"
  end

  context "when neither Pitchfork nor Unicorn is defined" do
    it "raises an error" do
      stats = class_spy("Promenade::Raindrops::Stats").as_stubbed_const

      expect do
        after_reply = []
        described_class.new(app).call({ "rack.after_reply" => after_reply })
        after_reply.each(&:call)
      end.to raise_error "Promenade::Raindrops::Middleware expects either ::Pitchfork or ::Unicorn to be defined"
    end
  end
end

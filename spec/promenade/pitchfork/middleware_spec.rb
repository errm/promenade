require "promenade/pitchfork/middleware"

RSpec.describe Promenade::Pitchfork::Middleware do
  let(:app) { double(:app, call: nil) }

  it "is add it's instrumentaion to the rack.after_reply" do
    stats = class_spy("Promenade::Pitchfork::Stats").as_stubbed_const

    after_reply = []
    described_class.new(app).call({ "rack.after_reply" => after_reply })
    after_reply.each(&:call)

    expect(stats).to have_received(:instrument)
  end
end

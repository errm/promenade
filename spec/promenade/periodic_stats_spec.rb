require "spec_helper"

RSpec.describe Promenade::PeriodicStats do
  describe "#start" do
    it "executes the block at the specified frequency" do
      counter = 0
      Promenade::PeriodicStats.configure(frequency: 0.1) { counter += 1 }
      Promenade::PeriodicStats.start

      sleep(0.2)
      Promenade::PeriodicStats.stop

      expect(counter).to be > 1
    end
  end
end

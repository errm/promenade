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

    it "swalows any errors, and logs them" do
      logger = double(:logger, error: nil)
      expect(logger).to receive(:error).with("Promenade: Error in periodic stats: Intentionally Broken")

      Promenade::PeriodicStats.configure(frequency: 0.1, logger: logger) { fail "Intentionally Broken" }
      Promenade::PeriodicStats.start

      sleep(0.2)
      Promenade::PeriodicStats.stop
    end
  end
end

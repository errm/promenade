require "singleton"

module Promenade
  class PeriodicStats
    include Singleton

    def initialize
      @thread_stopped = true
      @thread = nil
    end

    def self.configure(frequency:, logger: nil, &block)
      instance.configure(frequency: frequency, logger: logger, &block)
    end

    def self.start
      instance.start
    end

    def self.stop
      instance.stop
    end

    def configure(frequency:, logger: nil, &block)
      @frequency = frequency
      @block = block
      @logger = logger
    end

    def start
      stop

      @thread_stopped = false
      @thread = Thread.new do
        while active?
          begin
            block.call
          rescue StandardError => e
            logger&.error("Promenade: Error in periodic stats: #{e.message}")
          end
          sleep(frequency) # Ensure the sleep is inside the loop
        end
      end
    end

    def stop
      return unless thread

      if started?
        @thread_stopped = true
        thread.kill
        thread.join
      end

      @thread = nil
    end

    private

      attr_reader :logger, :frequency, :block, :thread, :thread_stopped

      def started?
        thread&.alive?
      end

      def active?
        !thread_stopped
      end
  end
end

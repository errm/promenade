begin
  require "raindrops"
rescue LoadError
  # No raindrops available, dont do anything
end

module Promenade
  module Raindrops
    Promenade.gauge :rack_active_workers do
      doc "Number of active workers in the Application Server"
    end

    Promenade.gauge :rack_queued_requests do
      doc "Number of requests waiting to be processed by the Application Server"
    end

    class Stats
      attr_reader :active_workers, :queued_requests, :listener_address

      def initialize(listener_address: nil)
        return unless defined?(::Raindrops)
        return unless defined?(::Raindrops::Linux.tcp_listener_stats)

        @listener_address = listener_address || "127.0.0.1:#{ENV.fetch('PORT', 3000)}"

        stats = ::Raindrops::Linux.tcp_listener_stats([@listener_address])[@listener_address]

        @active_workers = stats.active
        @queued_requests = stats.queued
      end

      def instrument
        Promenade.metric(:rack_active_workers).set({}, active_workers) if active_workers
        Promenade.metric(:rack_queued_requests).set({}, queued_requests) if queued_requests
      end

      def self.instrument(listener_address: nil)
        new(listener_address: listener_address).instrument
      end
    end
  end
end

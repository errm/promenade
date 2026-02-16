require "promenade/raindrops/stats"

module Promenade
  module Pitchfork
    class Stats
      Promenade.gauge :pitchfork_workers_count do
        doc "Number of workers configured"
      end

      Promenade.gauge :pitchfork_live_workers_count do
        doc "Number of live / booted workers"
      end

      Promenade.gauge :pitchfork_capacity do
        doc "Number of workers that are currently idle"
      end

      Promenade.gauge :pitchfork_busy_percent do
        doc "Percentage of workers that are currently busy"
      end

      def initialize
        return unless defined?(::Pitchfork::Info)

        @workers_count = ::Pitchfork::Info.workers_count
        @live_workers_count = ::Pitchfork::Info.live_workers_count

        raindrops_stats = Raindrops::Stats.new

        @active_workers = raindrops_stats.active_workers || 0
        @queued_requests = raindrops_stats.queued_requests || 0
      end

      def instrument
        Promenade.metric(:pitchfork_workers_count).set({}, workers_count)
        Promenade.metric(:pitchfork_live_workers_count).set({}, live_workers_count)
        Promenade.metric(:pitchfork_capacity).set({}, capacity)
        Promenade.metric(:pitchfork_busy_percent).set({}, busy_percent)
      end

      def self.instrument
        new.instrument
      end

      private

        attr_reader :workers_count, :live_workers_count, :active_workers, :queued_requests

        def capacity
          return 0 if live_workers_count.nil? || live_workers_count == 0

          live_workers_count - active_workers
        end

        def busy_percent
          return 0 if live_workers_count == 0

          (active_workers.to_f / live_workers_count) * 100
        end
    end
  end
end

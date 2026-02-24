module Promenade
  module Pitchfork
    class Stats
      Promenade.gauge :pitchfork_workers do
        doc "Number of workers configured"
        multiprocess_mode :max
      end

      Promenade.gauge :pitchfork_live_workers do
        doc "Number of live / booted workers"
        multiprocess_mode :max
      end

      def instrument
        Promenade.metric(:pitchfork_workers).set({}, workers_count)
        Promenade.metric(:pitchfork_live_workers).set({}, live_workers_count)
      end

      def self.instrument
        new.instrument
      end

      private

        def workers_count
          return unless defined?(::Pitchfork::Info)

          ::Pitchfork::Info.workers_count
        end

        def live_workers_count
          return unless defined?(::Pitchfork::Info)

          ::Pitchfork::Info.live_workers_count
        end
    end
  end
end

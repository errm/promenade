require "promenade/pitchfork/stats"
require "promenade/pitchfork/mem_stats"

module Promenade
  module Pitchfork
    class Middleware
      RACK_AFTER_REPLY = "rack.after_reply".freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        if env.key?(RACK_AFTER_REPLY)
          env[RACK_AFTER_REPLY] << -> { instrument }
        end
        @app.call(env)
      end

      private

        def instrument
          Promenade::Pitchfork::Stats.instrument
          Promenade::Pitchfork::MemStats.instrument
        end
    end
  end
end

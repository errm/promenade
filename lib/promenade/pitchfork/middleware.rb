require "promenade/pitchfork/stats"

module Promenade
  module Pitchfork
    class Middleware
      RACK_AFTER_REPLY = "rack.after_reply".freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        if env.key?(RACK_AFTER_REPLY)
          env[RACK_AFTER_REPLY] << -> {
            ::Promenade::Pitchfork::Stats.instrument
          }
        end
        @app.call(env)
      end
    end
  end
end

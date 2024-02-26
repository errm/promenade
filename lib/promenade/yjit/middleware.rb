require "promenade/yjit/stats"

module Promenade
  module YJIT
    class Middlware
      RACK_AFTER_REPLY = "rack.after_reply".freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        if env.key?(RACK_AFTER_REPLY)
          env[RACK_AFTER_REPLY] << -> {
            ::Promenade::YJIT::Stats.instrument
          }
        end
        @app.call(env)
      end
    end
  end
end

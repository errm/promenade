require "promenade/raindrops/stats"

module Promenade
  module Raindrops
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

        def tcp_listener_names
          if defined?(::Pitchfork)
            ::Pitchfork.listener_names
          elsif defined?(::Unicorn)
            ::Unicorn.listener_names
          else
            raise StandardError,
              "Promenade::Raindrops::Middleware expects either ::Pitchfork or ::Unicorn to be defined"
          end
        end

        def instrument
          tcp_listener_names.each do |name|
            Promenade::Raindrops::Stats.instrument(listener_address: name)
          end
        end
    end
  end
end

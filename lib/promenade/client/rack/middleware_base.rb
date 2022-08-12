require "prometheus/client"
require_relative "request_labeler"

module Promenade
  module Client
    module Rack
      class MiddlwareBase
        def initialize(app, registry:, label_builder:)
          @app = app
          @registry = registry
          @label_builder = label_builder

          register_metrics!
        end

        def call(env)
          trace(env) { app.call(env) }
        end

        private

          attr_reader :app, :label_builder, :registry

          def trace(env)
            raise NotImplementedError,
              "Please define #{__method__} in #{self.class}"
          end

          def labels(env, response)
            label_builder.call(env).merge!(code: response.first.to_s)
          end

          def register_metrics!
            # :noop:
          end
      end
    end
  end
end

require_relative "singleton_caller"
require_relative "request_labeler"

module Promenade
  module Client
    module Rack
      class ExceptionHandler
        extend SingletonCaller

        attr_reader :histogram_name, :requests_counter_name, :exceptions_counter_name, :registry

        def initialize(histogram_name:, requests_counter_name:, exceptions_counter_name:, registry:)
          @histogram_name = histogram_name
          @requests_counter_name = requests_counter_name
          @exceptions_counter_name = exceptions_counter_name
          @registry = registry
        end

        def call(exception, env_hash, duration)
          labels = RequestLabeler.call(env_hash)
          histogram.observe(labels, duration)
          requests_counter.increment(labels)
          exceptions_counter.increment(exception: exception.class.name)

          raise exception
        end

        private

          def histogram
            registry.get(histogram_name)
          end

          def requests_counter
            registry.get(requests_counter_name)
          end

          def exceptions_counter
            registry.get(exceptions_counter_name)
          end
      end
    end
  end
end

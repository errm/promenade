module Promenade
  module Client
    module Rack
      module SingletonCaller
        def initialize_singleton(*args, **keyword_args, &block)
          @singleton = new(*args, **keyword_args, &block)
        end

        def call(*args, **keyword_args, &block)
          singleton.call(*args, **keyword_args, &block)
        end

        def singleton
          @singleton || initialize_singleton
        end
      end
    end
  end
end

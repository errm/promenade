module Promenade
  module Client
    module Rack
      module SingletonCaller
        if RUBY_VERSION < "3.0"
          def initialize_singleton(*args)
            @singleton = new(*args)
          end

          def call(*args)
            singleton.call(*args)
          end
        else
          def initialize_singleton(*args, **keyword_args, &block)
            @singleton = new(*args, **keyword_args, &block)
          end

          def call(*args, **keyword_args, &block)
            singleton.call(*args, **keyword_args, &block)
          end
        end

        def singleton
          @singleton || initialize_singleton
        end
      end
    end
  end
end

# rubocop:disable Lint/Syntax
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
          def initialize_singleton(...)
            @singleton = new(...)
          end

          def call(...)
            singleton.call(...)
          end
        end

        def singleton
          @singleton || initialize_singleton
        end
      end
    end
  end
end
# rubocop:enable Lint/Syntax
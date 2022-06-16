module Promenade
  module Client
    module Rack
      module SingletonCaller
        def initialize_singleton(...)
          @singleton = new(...)
        end

        def call(...)
          singleton.call(...)
        end

        def singleton
          @singleton || initialize_singleton
        end
      end
    end
  end
end

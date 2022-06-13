module Promenade
  module Client
    module Rack
      module SingletonCaller
        def initialize_singleton(*args)
          @singleton = new(*args)
        end

        def call(*args)
          singleton.call(*args)
        end

        def singleton
          @singleton || initialize_singleton
        end
      end
    end
  end
end

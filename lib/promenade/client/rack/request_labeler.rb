module Promenade
  module Client
    module Rack
      class RequestLabeler
        require_relative "singleton_caller"
        extend SingletonCaller

        HTTP_HOST = "HTTP_HOST".freeze

        private_constant :HTTP_HOST

        def call(env)
          {
            host: env[HTTP_HOST].to_s,
          }
        end
      end
    end
  end
end

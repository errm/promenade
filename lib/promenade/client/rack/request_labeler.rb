module Promenade
  module Client
    module Rack
      class RequestLabeler
        require_relative "singleton_caller"
        extend SingletonCaller

        REQUEST_METHOD = "REQUEST_METHOD".freeze

        HTTP_HOST = "HTTP_HOST".freeze

        private_constant :REQUEST_METHOD, :HTTP_HOST

        def call(env)
          {
            method: env[REQUEST_METHOD].to_s.downcase,
            host: env[HTTP_HOST].to_s,
          }
        end
      end
    end
  end
end

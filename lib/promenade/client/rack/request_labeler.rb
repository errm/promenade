module Promenade
  module Client
    module Rack
      class RequestLabeler
        require_relative "singleton_caller"
        extend SingletonCaller

        REQUEST_METHOD = "REQUEST_METHOD".freeze

        HTTP_HOST = "HTTP_HOST".freeze

        PARAMS_KEY = "action_dispatch.request.parameters".freeze

        PATH_PARAMS_KEY = "action_dispatch.request.path_parameters".freeze

        CONTROLLER = "controller".freeze

        ACTION = "action".freeze

        UNKNOWN = "unknown".freeze

        SEPARATOR = "#".freeze

        private_constant :REQUEST_METHOD, :HTTP_HOST, :PARAMS_KEY, :CONTROLLER, :ACTION, :UNKNOWN, :SEPARATOR

        def call(env)
          {
            method: env[REQUEST_METHOD].to_s.downcase,
            host: env[HTTP_HOST].to_s,
            controller_action: controller_action_from_env(env),
          }
        end

        private

          def controller_action_from_env(env)
            controller = env.dig(PARAMS_KEY, CONTROLLER) ||
                         env.dig(PATH_PARAMS_KEY, CONTROLLER.to_sym) ||
                         UNKNOWN

            action = env.dig(PARAMS_KEY, ACTION) ||
                     env.dig(PATH_PARAMS_KEY, ACTION.to_sym) ||
                     UNKNOWN

            [controller, action].join(SEPARATOR)
          end
      end
    end
  end
end

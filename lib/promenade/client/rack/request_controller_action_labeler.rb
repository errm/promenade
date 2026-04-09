require_relative "request_labeler"
module Promenade
  module Client
    module Rack
      class RequestControllerActionLabeler < RequestLabeler
        PARAMS_KEY = "action_dispatch.request.parameters".freeze

        PATH_PARAMS_KEY = "action_dispatch.request.path_parameters".freeze

        CONTROLLER = "controller".freeze

        ACTION = "action".freeze

        UNKNOWN = "unknown".freeze

        SEPARATOR = "#".freeze

        REQUEST_METHOD = "REQUEST_METHOD".freeze

        private_constant :PARAMS_KEY, :CONTROLLER, :ACTION, :UNKNOWN, :SEPARATOR, :REQUEST_METHOD

        def call(env)
          super.merge({
            controller_action: controller_action_from_env(env),
            method: env[REQUEST_METHOD].to_s.downcase,
          })
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

require_relative "boot"

%w(
  action_controller/railtie
  action_view/railtie
).each do |railtie|
  require railtie
end


# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require "promenade"
require "promenade/railtie"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    # For compatibility with applications that use this config
    config.action_controller.include_all_helpers = false
  end
end

require "promenade/setup"
require "promenade/engine"
require "promenade/client/rack/collector"

module Promenade
  class Railtie < ::Rails::Railtie
    initializer "promenade.configure_rails_initialization" do
      Promenade.setup
      Rails.application.config.middleware.insert_after ActionDispatch::ShowExceptions,
        Promenade::Client::Rack::Collector
    end
  end
end

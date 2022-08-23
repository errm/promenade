require "promenade/setup"
require "promenade/engine"
require "promenade/client/rack/http_request_duration_collector"
require "promenade/client/rack/http_request_queue_time_collector"

module Promenade
  class Railtie < ::Rails::Railtie
    initializer "promenade.configure_rails_initialization" do
      Promenade.setup
      Rails.application.config.middleware.insert_after ActionDispatch::ShowExceptions,
        Promenade::Client::Rack::HTTPRequestDurationCollector
      Rails.application.config.middleware.insert_after ActionDispatch::ShowExceptions,
        Promenade::Client::Rack::HTTPRequestQueueTimeCollector
    end
  end
end

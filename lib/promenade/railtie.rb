require "promenade/setup"
require "promenade/engine"
require "promenade/client/rack/http_request_duration_collector"
require "promenade/client/rack/http_request_queue_time_collector"
require "promenade/yjit/middleware"

module Promenade
  class Railtie < ::Rails::Railtie
    initializer "promenade.configure_rails_initialization" do
      Promenade.setup
      Rails.application.config.middleware.use Promenade::YJIT::Middlware if defined? ::RubyVM::YJIT
      Rails.application.config.middleware.insert_after ActionDispatch::ShowExceptions,
        Promenade::Client::Rack::HTTPRequestDurationCollector
      Rails.application.config.middleware.insert 0,
        Promenade::Client::Rack::HTTPRequestQueueTimeCollector
    end

    initializer "promenade.configure_middlewares", after: :load_config_initializers do
      pitchfork_stats_enabled = Promenade.configuration.pitchfork_stats_enabled

      if pitchfork_stats_enabled && defined?(::Raindrops)
        require "promenade/raindrops/middleware"
        Rails.application.config.middleware.use Promenade::Raindrops::Middleware
      end

      if pitchfork_stats_enabled && defined?(::Pitchfork)
        require "promenade/pitchfork/middleware"
        Rails.application.config.middleware.use Promenade::Pitchfork::Middleware
      end
    end
  end
end

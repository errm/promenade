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

      if defined?(::Raindrops) && (defined?(::Pitchfork) || defined?(::Unicorn))
        require "promenade/raindrops/middleware"
        Rails.application.config.middleware.use Promenade::Raindrops::Middleware
      end

      if defined?(::Pitchfork)
        require "promenade/pitchfork/middleware"
        Rails.application.config.middleware.use Promenade::Pitchfork::Middleware
      end
    end
  end
end

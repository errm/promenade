require "promenade/version"
require "promenade/setup"
require "promenade/configuration"
require "promenade/prometheus"

module Promenade
  class << self
    %i(gauge counter summary histogram).each do |type|
      define_method type do |*args, &block|
        Promenade::Prometheus.define_metric(type, *args, &block)
      end
    end

    def metric(name)
      Promenade::Prometheus.metric(name)
    end

    def configuration
      @_configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end

require "promenade/railtie" if defined? Rails::Railtie

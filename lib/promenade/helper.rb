require "promenade/prometheus"

module Promenade
  module Helper
    extend ActiveSupport::Concern

    class_methods do
      %i(gauge counter summary histogram).each do |type|
        define_method type do |*args, &block|
          Promenade::Prometheus.define_metric(type, *args, &block)
        end
      end

      def metric(name)
        Promenade::Prometheus.metric(name)
      end
    end

    def metric(name)
      Promenade::Prometheus.metric(name)
    end
  end
end

require "promenade"
require "active_support/concern"
require "prometheus/client"

module Promenade
  module Prometheus
    extend ActiveSupport::Concern

    REGISTRY_MUTEX = Mutex.new
    METRICS_MUTEX  = Mutex.new

    def self.metric(name)
      METRICS_MUTEX.synchronize do
        registry.get(name) ||
          fail("No metric defined for: #{name}, you must define a metric before using it")
      end
    end

    def self.define_metric(type, name, &block)
      METRICS_MUTEX.synchronize do
        return if registry.get(name)

        registry.register(DSL.new(type, name).evaluate(&block).metric)
      end
    end

    def self.registry
      REGISTRY_MUTEX.synchronize do
        @_registry ||= ::Prometheus::Client.registry
      end
    end

    class DSL
      BUCKET_PRESETS = {
        network: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].freeze,
        memory: (0..10).map { |i| 128 * 2**i },
      }.freeze

      def initialize(type, name)
        @type = type
        @name = name
        @buckets = BUCKET_PRESETS[:network]
        @labels = []
        @preset_labels = {}
        @doc = nil
      end

      def doc(str)
        @doc = str
      end

      def labels(labels)
        @labels = labels
      end

      def preset_labels(labels)
        @preset_labels = labels
      end

      def buckets(buckets)
        if buckets.is_a?(Symbol)
          @buckets = BUCKET_PRESETS[buckets]
          fail "#{buckets} is not a valid bucket preset" if @buckets.nil?
        else
          @buckets = buckets
        end
      end

      def metric
        ::Prometheus::Client.const_get(@type.to_s.capitalize).new(
          @name,
          args,
        )
      rescue NameError
        fail "Unsupported metric type: #{@type}"
      end

      def evaluate(&block)
        instance_eval(&block)
        self
      end

      private

        def args
          metric_args = { docstring: @doc, labels: @labels, preset_labels: @preset_labels }
          @type == :histogram ? metric_args.merge(buckets: @buckets) : metric_args
        end
    end
  end
end

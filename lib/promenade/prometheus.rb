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
        fail("Metric: #{name}, is allready defined") if registry.get(name)
        options = Options.new
        options.evaluate(&block)
        registry.method(type).call(name, *options.args(type))
      end
    end

    def self.registry
      @_registry ||= begin
                       REGISTRY_MUTEX.synchronize do
                         ::Prometheus::Client.registry
                       end
                     end
    end

    def self.reset!
      @_registry = nil
      ::Prometheus::Client.reset!
    end
  end

  class Options
    BUCKET_PRESETS = {
      network: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].freeze,
    }.freeze

    def initialize
      @buckets = BUCKET_PRESETS[:network]
      @base_labels = {}
      @doc = nil
      @multiprocess_mode = :all
    end

    def doc(str)
      @doc = str
    end

    def base_labels(labels)
      @base_labels = labels
    end

    def multiprocess_mode(mode)
      @multiprocess_mode = mode
    end

    def buckets(buckets)
      if buckets.is_a?(Symbol)
        @buckets = BUCKET_PRESETS[buckets]
        fail "#{buckets} is not a valid bucket preset" if @buckets.nil?
      else
        @buckets = buckets
      end
    end

    def args(type)
      case type
      when :gauge
        [@doc, @base_labels, @multiprocess_mode]
      when :histogram
        [@doc, @base_labels, @buckets]
      when :counter, :summary
        [@doc, @base_labels]
      else
        fail "Unsupported metric type: #{type}"
      end
    end

    def evaluate(&block)
      instance_eval(&block) if block_given?
      self
    end
  end
end

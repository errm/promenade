module Promenade
  class Configuration
    attr_accessor :rack_latency_buckets

    DEFAULT_RACK_LATENCY_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].freeze

    def initialize
      @rack_latency_buckets = DEFAULT_RACK_LATENCY_BUCKETS
    end
  end
end

module Promenade
  class Configuration
    attr_accessor :queue_time_buckets, :rack_latency_buckets

    DEFAULT_RACK_LATENCY_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].freeze

    # 2ms to 20ms in intervals of 2ms
    DEFAULT_QUEUE_TIME_BUCKETS = [0.002, 0.004, 0.006, 0.008, 0.01, 0.012, 0.014, 0.016, 0.018, 0.02].freeze

    def initialize
      @rack_latency_buckets = DEFAULT_RACK_LATENCY_BUCKETS
      @queue_time_buckets = DEFAULT_QUEUE_TIME_BUCKETS
    end
  end
end

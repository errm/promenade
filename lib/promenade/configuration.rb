module Promenade
  class Configuration
    attr_accessor :queue_time_buckets, :rack_latency_buckets, :pitchfork_stats_enabled

    DEFAULT_RACK_LATENCY_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].freeze

    DEFAULT_QUEUE_TIME_BUCKETS = [0.01, 0.5, 1.0, 10.0, 30.0].freeze

    def initialize
      @rack_latency_buckets = DEFAULT_RACK_LATENCY_BUCKETS
      @queue_time_buckets = DEFAULT_QUEUE_TIME_BUCKETS
      @pitchfork_stats_enabled = false
    end
  end
end

module PrometheusMatchers
  class CounterValuesMatcher
    attr_reader :expected_count
    attr_accessor :labels, :counter

    def initialize(expected_count)
      @expected_count = expected_count
    end

    def matches?(test_counter)
      self.counter = test_counter
      time_series_data && time_series_data.get == expected_count
    end

    def with_labels(labels = {})
      self.labels = labels
      self
    end

    private

      def time_series_data
        if labels.blank?
          raise EmptyLabelsError, "Cannot find time series data without labels hash. Please call `with_labels()`"
        end

        counter.values[labels]
      end
  end

  class HistogramValuesMatcher
    class EmptyLabelsError < StandardError; end

    attr_reader :expected_count
    attr_accessor :ge_bucket_value, :histogram, :labels, :lt_bucket_value

    def initialize(expected_count)
      @expected_count = expected_count
    end

    def matches?(test_histogram)
      self.histogram = test_histogram

      matching_time_series_data.any? && matching_time_series_data.values.all?(expected_count)
    end

    def with_labels(labels = {})
      self.labels = labels
      self
    end

    def for_buckets_greater_than_or_equal_to(bucket_value)
      self.ge_bucket_value = bucket_value
      self
    end

    def for_buckets_less_than(bucket_value)
      self.lt_bucket_value = bucket_value
      self
    end

    private

      def failure_message
        string = "expected that #{histogram.name} would have a count of #{expected_count}"
        condition_strings = []
        if greater_than_or_equal_to?
          condition_strings << " for all buckets greater than or equal to #{ge_bucket_value}"
        elsif less_than?
          condition_strings << " for all buckets less than #{lt_bucket_value}"
        end
        string + condition_strings.join("and") + "; but data was #{matching_time_series_data}"
      end

      def greater_than_or_equal_to?
        !!@ge_bucket_value
      end

      def less_than?
        !!@lt_bucket_value
      end

      def time_series_data
        if labels.blank?
          raise EmptyLabelsError, "Cannot find time series data without labels hash. Please call `with_labels()`"
        end

        histogram.values[labels].transform_values(&:get)
      end

      def matching_time_series_data
        @_matching_time_series_data ||= begin
          data_to_filter = time_series_data
          if greater_than_or_equal_to?
            data_to_filter.keep_if { |bucket, _| bucket >= ge_bucket_value }
          end

          if less_than?
            data_to_filter.keep_if { |bucket, _| bucket < lt_bucket_value }
          end
          data_to_filter
        end
      end
  end

  private_constant :HistogramValuesMatcher

  def have_time_series_value(expected_count)
    HistogramValuesMatcher.new(expected_count)
  end

  def have_time_series_count(expected_count)
    CounterValuesMatcher.new(expected_count)
  end
end

RSpec.configure do |config|
  config.include(PrometheusMatchers)
end

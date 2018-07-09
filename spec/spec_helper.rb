require "deep_cover/builtin_takeover"
require "simplecov"
SimpleCov.minimum_coverage 99
SimpleCov.start

if ENV["CI"]
  require "codecov"
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require "bundler/setup"
require "climate_control"
require "promenade"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.before(:each) do |_example|
    ::Prometheus::Client.registry.reset!
    allow(Prometheus::Client.configuration).to receive(:value_class).and_return(Prometheus::Client::SimpleValue)
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

module Prometheus
  module Client
    class Registry
      def reset!
        @metrics.each do |key, metric|
          if key.to_s.match?(/promenade_testing_.*/)
            @metrics.delete(key)
          end
          metric.reset!
        end
      end
    end

    class Metric
      def reset!
        @values = Hash.new { |hash, key| hash[key] = default(key) }
      end
    end
  end
end

require "simplecov"
SimpleCov.minimum_coverage 99
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/promenade/railtie.rb"
end

if ENV["CI"]
  require "simplecov-cobertura"
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
end

require "bundler/setup"
require "climate_control"
require "promenade"
require "byebug"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.before(:each) do |_example|
    Prometheus::Client.registry.reset!
    allow(Prometheus::Client.configuration).to receive(:value_class).and_return(Prometheus::Client::SimpleValue)
  end

  # Some specs require the same prometheus client between examples, others expect a fresh start.
  # This allows support for both with the tag :reset_prometheus_client => true
  config.around(:each, reset_prometheus_client: true) do |example|
    main_registry = Prometheus::Client.registry
    Prometheus::Client.instance_variable_set(:@registry, nil)
    example.run
    Prometheus::Client.instance_variable_set(:@registry, main_registry)
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

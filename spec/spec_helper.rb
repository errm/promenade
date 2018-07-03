require "simplecov"
SimpleCov.minimum_coverage 100
SimpleCov.start

require "bundler/setup"
require "promenade"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.before(:each) do
    Promenade::Prometheus.reset! if Promenade.const_defined? :Prometheus
    allow(Prometheus::Client.configuration).to receive(:value_class).and_return(Prometheus::Client::SimpleValue)
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

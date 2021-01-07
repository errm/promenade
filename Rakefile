require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i(spec rubocop integration)

task :clean do
  sh "rm -rf tmp/promenade"
end

task integration: :clean do
  sh "bin/integration_test"
end

task spec: :clean

task release: :default

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i(spec rubocop)

task :clean do
  sh "rm -rf tmp/promenade"
end

task spec: :clean

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new do |task|
  task.patterns = ['lib/**/*.rb', 'spec/**/*.rb', 'exe/**']
end

task default: %i(spec rubocop)

task :clean do
  sh "rm -rf tmp/promenade"
end

task spec: :clean

task release: :spec

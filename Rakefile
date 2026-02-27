require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts = "--tag ~type:acceptance"
end
RuboCop::RakeTask.new

task default: %i(spec rubocop exporter acceptance:spec)

task :clean do
  sh "rm -rf tmp/promenade"
end

namespace :acceptance do
  task prepare: [:build] do
    FileUtils.rm_rf "example/gem/promenade"
    gem = Dir.glob("pkg/promenade-*.gem").max
    sh "gem unpack #{gem} --target=example/gem"
    unpacked = Dir.glob("example/gem/promenade-*").max
    FileUtils.mv(unpacked, "example/gem/promenade")

    Dir.chdir("example") do
      sh "bundle install"
    end

    unless ENV["CI"]
      sh "docker compose up --build --detach"
    end
  end

  RSpec::Core::RakeTask.new(:spec) do |task|
    task.rspec_opts = "--tag type:acceptance"
  end

  task spec: :prepare
end

task :exporter do
  Dir.chdir("exporter") do
    sh "go test -v ./..."
  end
end

task spec: :clean

task release: :default

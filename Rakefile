require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "net/http"
require "uri"

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

    sh "docker compose up --build --detach"

    sleep 1 until check_url("http://localhost:9394/metrics")
    sleep 1 until check_url("http://localhost:3000/up")
  end

  RSpec::Core::RakeTask.new(:spec) do |task|
    task.rspec_opts = "--tag type:acceptance"
  end

  task spec: [:prepare, :cleanup]

  task :cleanup do
    at_exit {
      sh "docker compose logs"
      sh "docker compose down"
    }
  end
end

def check_url(url)
  Net::HTTP.get_response(URI(url)).code == "200"
rescue Errno::ECONNREFUSED => e
  puts e
  false
end

task :exporter do
  Dir.chdir("exporter") do
    sh "go test -v ./..."
  end
end

task spec: :clean

task release: :default

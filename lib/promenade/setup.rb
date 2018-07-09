require "prometheus/client"
require "prometheus/client/support/unicorn"

module Promenade
  def self.root_dir
    rails_root = defined?(Rails) && Rails.root
    rails_root || Pathname.new(ENV.fetch("RAILS_ROOT", Dir.pwd))
  end

  def self.multiprocess_files_dir
    ENV.fetch("PROMETHEUS_MULTIPROC_DIR", root_dir.join("tmp", "promenade"))
  end

  def self.setup
    unless File.directory? multiprocess_files_dir
      FileUtils.mkdir_p multiprocess_files_dir
    end

    ::Prometheus::Client.configure do |config|
      config.multiprocess_files_dir = multiprocess_files_dir
      config.pid_provider = ::Prometheus::Client::Support::Unicorn.method(:worker_pid_provider)
    end
  end
end

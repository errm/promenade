require "pathname"

module Promenade
  module_function

  def root_dir
    if rails_defined?
      Rails.root
    else
      Pathname.new(ENV.fetch("RAILS_ROOT", Dir.pwd))
    end
  end

  def rails_defined?
    defined?(Rails)
  end

  def multiprocess_files_dir
    ENV.fetch("PROMETHEUS_MULTIPROC_DIR", root_dir.join("tmp", "promenade"))
  end

  def setup
    unless File.directory? multiprocess_files_dir
      FileUtils.mkdir_p multiprocess_files_dir
    end

    ENV["prometheus_multiproc_dir"] = multiprocess_files_dir.to_s

    require "prometheus/client"
    require "prometheus/client/support/unicorn"

    ::Prometheus::Client.configure do |config|
      config.multiprocess_files_dir = multiprocess_files_dir
      config.pid_provider = ::Prometheus::Client::Support::Unicorn.method(:worker_pid_provider)
    end
  end
end

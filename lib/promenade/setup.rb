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

    ::Prometheus::Client.configure do |config|
      config.multiprocess_files_dir = multiprocess_files_dir

      # This workaround enables us to utilize the same PID provider for both Unicorn, Pitchfork and Puma.
      # We cannot employ the same method directly because Unicorn and Pitchfork are not loaded simultaneously.
      # Instead, we define a method that dynamically loads the appropriate PID provider based on the active server.
      # As a fallback, we use the process ID.

      if defined?(Unicorn)
        require "prometheus/client/support/unicorn"
        pid_provider_method = ::Prometheus::Client::Support::Unicorn.method(:worker_pid_provider)
      elsif defined?(::Pitchfork)
        require "promenade/pitchfork/worker_pid_provider"
        pid_provider_method = Pitchfork::WorkerPidProvider.method(:fetch)
      elsif defined?(::Puma)
        require "prometheus/client/support/puma"
        pid_provider_method = ::Prometheus::Client::Support::Puma.method(:worker_pid_provider)
      else
        pid_provider_method = -> { "process_id_#{Process.pid}" }
      end

      config.pid_provider = pid_provider_method
    end
  end
end

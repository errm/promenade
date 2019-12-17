require "pathname"
require "prometheus/client"
require "prometheus/client/data_stores/direct_file_store"

module Promenade
  def self.root_dir
    rails_root = defined?(Rails) && Rails.root
    rails_root || Pathname.new(ENV.fetch("RAILS_ROOT", Dir.pwd))
  end

  def self.multiprocess_files_dir
    ENV.fetch("PROMETHEUS_MULTIPROC_DIR", root_dir.join("tmp", "promenade").to_s)
  end

  def self.setup
    unless File.directory? multiprocess_files_dir
      FileUtils.mkdir_p multiprocess_files_dir
    end

    ::Prometheus::Client.config.data_store = ::Prometheus::Client::DataStores::DirectFileStore.new(
      dir: multiprocess_files_dir,
    )
  end
end

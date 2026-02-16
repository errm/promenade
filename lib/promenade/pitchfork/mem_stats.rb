begin
  require "pitchfork/mem_info"
rescue LoadError
  # No pitchfork available, dont do anything
end

module Promenade
  module Pitchfork
    class MemStats
      Promenade.gauge :pitchfork_memory_usage_bytes do
        doc "Memory usage in bytes, broken down by type (RSS, PSS, SHARED_MEMORY)"
      end

      def initialize
        return unless defined?(::Pitchfork::MemInfo)

        @mem_info = ::Pitchfork::MemInfo.new(Process.pid)
      end

      def instrument
        Promenade.metric(:pitchfork_memory_usage_bytes).set({ type: "RSS" }, @mem_info.rss * 1024)
        Promenade.metric(:pitchfork_memory_usage_bytes).set({ type: "PSS" }, @mem_info.pss * 1024)
        Promenade.metric(:pitchfork_memory_usage_bytes).set({ type: "Shared" }, @mem_info.shared_memory * 1024)
      end

      def self.instrument
        new.instrument
      rescue StandardError
      end
    end
  end
end

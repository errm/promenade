begin
  require "pitchfork/mem_info"
rescue LoadError
  # No pitchfork available, dont do anything
end

module Promenade
  module Pitchfork
    class MemStats
      Promenade.gauge :pitchfork_mem_rss do
        doc "Resident Set Size of the pitchfork process, Total memory used by the process."
      end

      Promenade.gauge :pitchfork_shared_mem do
        doc "Shared memory of the pitchfork process, memory that is shared between multiple processes."
      end

      def initialize
        return unless defined?(::Pitchfork) && defined?(::Pitchfork::MemInfo)

        @mem_info = ::Pitchfork::MemInfo.new(Process.pid)
        @parent_mem_info = ::Pitchfork::MemInfo.new(Process.ppid)
      end

      def instrument
        Promenade.metric(:pitchfork_mem_rss).set({}, @mem_info.rss)
        Promenade.metric(:pitchfork_shared_mem).set({}, @mem_info.shared_memory)
      end

      def self.instrument
        new.instrument
      rescue StandardError
      end
    end
  end
end

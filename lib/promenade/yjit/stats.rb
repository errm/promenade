module Promenade
  module YJIT
    class Stats
      Promenade.gauge :ruby_yjit_code_region_size do
        doc "Ruby YJIT code size"
      end

      def self.instrument
        return unless defined?(::RubyVM::YJIT) && ::RubyVM::YJIT.enabled?

        Promenade.metric(:ruby_yjit_code_region_size).set({}, ::RubyVM::YJIT.runtime_stats[:code_region_size])
      end
    end
  end
end

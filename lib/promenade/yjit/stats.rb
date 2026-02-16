module Promenade
  module YJIT
    class Stats
      RUNTIME_STATS = %i(
        code_region_size
        ratio_in_yjit
      ).freeze

      Promenade.gauge :ruby_yjit_code_region_size do
        doc "Ruby YJIT code size"
      end

      Promenade.gauge :ruby_yjit_ratio_in_yjit do
        doc "Shows the ratio of YJIT-executed instructions in %"
      end

      def self.instrument
        return unless defined?(::RubyVM::YJIT) && ::RubyVM::YJIT.enabled?

        ::RubyVM::YJIT.runtime_stats.slice(*RUNTIME_STATS).each do |stat, value|
          Promenade.metric(:"ruby_yjit_#{stat}").set({}, value)
        end
      end
    end
  end
end

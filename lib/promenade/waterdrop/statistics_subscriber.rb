require "promenade/waterdrop/subscriber"

module Promenade
  module Waterdrop
    class StatisticsSubscriber < Subscriber
      attach_to "statistics.waterdrop"

      def emitted(event)
        sum = event.payload[:statistics]["rxmsgs"]
        diff = event.payload[:statistics]["rxmsgs_d"]

        stat = {
          name: event.payload[:statistics]["name"],
          txmsgs: event.payload[:statistics]["txmsgs"],
          rxmsgs: event.payload[:statistics]["rxmsgs"],
          received_messages: sum,
          messages_from_last_statistics: diff
        }

        Rails.logger.info "[Statistics][waterdrop] #{stat.inspect}"
      end
    end
  end
end

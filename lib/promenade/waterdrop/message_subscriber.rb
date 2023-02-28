require "promenade/waterdrop/subscriber"

module Promenade
  module Waterdrop
    class StatisticsSubscriber < Subscriber
      attach_to "message.waterdrop"

      def produced_async(event)
        data = event.payload[:message].slice(:key, :topic).merge(producer_id: event.payload[:producer_id])

        Rails.logger.info("[waterdrop] produced_async: #{data.inspect}")
      end

      def produced_sync(event)
        data = event.payload[:message].slice(:key, :topic).merge(producer_id: event.payload[:producer_id])

        Rails.logger.info("[waterdrop] produced_sync: #{data.inspect}")
      end

      def acknowledged(event)
        Rails.logger.info "[waterdrop] message acknowledged: #{event.payload.inspect}"
      end
    end
  end
end

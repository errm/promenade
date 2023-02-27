require "promenade/karafka/subscriber"
require "promenade/karafka/processors/consumer_processor"

module Promenade
  class ConsumerSubscriber < Subscriber
    attach_to "consumer.kafka"

    def consumed(event)
      messages = event.payload[:caller].messages.map do |m|
        { type: m.payload["type"], event_time: m.payload["event_time"],
          id: m.payload.dig("body", "id") || "missing id for #{m.payload.inspect}" }
      end

      Logger.new($stdout).info "[kafka] consumed : #{messages.inspect}"

      Processors::ConsumerProcessor.call(event)
    end
  end
end

require "promenade/kafka/subscriber"

module Promenade
  module Kafka
    class FetcherSubscriber < Subscriber
      attach_to "fetcher.kafka"

      gauge :kafka_fetcher_queue_size do
        doc "Fetcher queue size"
      end

      def loop(event)
        queue_size = event.payload.fetch(:queue_size)
        client = event.payload.fetch(:client_id)
        group_id = event.payload.fetch(:group_id)

        metric(:kafka_fetcher_queue_size).set({ client: client, group: group_id }, queue_size)
      end
    end
  end
end

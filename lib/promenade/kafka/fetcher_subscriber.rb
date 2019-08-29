require "promenade/kafka/subscriber"

module Promenade
  module Kafka
    class FetcherSubscriber < Subscriber
      attach_to "fetcher.kafka"

      Promenade.gauge :kafka_fetcher_queue_size do
        doc "Fetcher queue size"
        labels %i(client group)
      end

      def loop(event)
        queue_size = event.payload.fetch(:queue_size)
        client = event.payload.fetch(:client_id)
        group_id = event.payload.fetch(:group_id)

        Promenade.metric(:kafka_fetcher_queue_size).set(queue_size, labels: { client: client, group: group_id })
      end
    end
  end
end

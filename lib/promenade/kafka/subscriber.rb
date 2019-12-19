require "active_support/subscriber"
require "concurrent/utility/monotonic_time"

module Promenade
  module Kafka
    class Subscriber < ActiveSupport::Subscriber
      private

        def get_labels(event)
          client = event.payload.fetch(:client_id)
          topic = event.payload.fetch(:topic)
          { client: client, topic: topic }
        end
    end
  end
end

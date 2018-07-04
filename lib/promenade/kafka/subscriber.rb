require "promenade/helper"
require "active_support/subscriber"

module Promenade
  module Kafka
    class Subscriber < ActiveSupport::Subscriber
      include ::Promenade::Helper

      private

        def get_labels(event)
          client = event.payload.fetch(:client_id)
          topic = event.payload.fetch(:topic)
          { client: client, topic: topic }
        end
    end
  end
end

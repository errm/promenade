require "active_support/subscriber"

module Promenade
  module Karafka
    class Subscriber < ActiveSupport::Subscriber
      private

        # TODO: to be implemented
        def get_labels(event)
          # client = event.payload.fetch(:client_id)
          # topic = event.payload.fetch(:topic)
          # { client: client, topic: topic }
          {}
        end
    end
  end
end

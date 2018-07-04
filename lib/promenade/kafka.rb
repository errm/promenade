require "promenade/kafka/producer_subscriber"

module Promenade
  module Kafka
    class Subscriber < ActiveSupport::Subscriber
      include ::Promenade::Helper
    end
  end
end

require "promenade/helper"
require "active_support/subscriber"

module Promenade
  module Kafka
    class Subscriber < ActiveSupport::Subscriber
      include ::Promenade::Helper
    end
  end
end

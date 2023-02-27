module Promenade
  module Karafka
    module Processors
      class ConsumerProcessor
        def self.call(event)
          # TODO: uncomeent after defining labels
          # new(event).call
        end

        def initialize(event)
          @event = event
        end

        def call
          send_metrics
        end

        private

          attr_reader :event

          def send_metrics
            Promenade.metric(:kafka_consumer_messages_processed).increment(labels, messages.count)
            Promenade.metric(:kafka_consumer_batch_processing_latency).observe(labels, event.duration)
          end

          def consumer
            @_consumer = event.payload[:caller]
          end

          def messages
            @_messages = consumer.messages
          end

          def metadata
            @_metadata = messages.metadata
          end

          # TODO: implement
          def labels
            {}
          end
      end
    end
  end
end

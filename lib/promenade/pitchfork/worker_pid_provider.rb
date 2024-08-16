module Promenade
  module Pitchfork
    class WorkerPidProvider
      def self.fetch
        worker_id || "process_id_#{Process.pid}"
      end

      def self.object_based_worker_id
        return unless defined?(::Pitchfork::Worker)

        workers = ObjectSpace.each_object(::Pitchfork::Worker)
        return if workers.nil?

        workers_first = workers.first
        workers_first&.nr
      end

      def self.program_name
        $PROGRAM_NAME
      end

      def self.worker_id
        if matchdata = program_name.match(/pitchfork.*worker\[(.+)\]/) # rubocop:disable Lint/AssignmentInCondition
          "pitchfork_#{matchdata[1]}"
        elsif object_worker_id = object_based_worker_id # rubocop:disable Lint/AssignmentInCondition
          "pitchfork_#{object_worker_id}"
        end
      end
    end
  end
end

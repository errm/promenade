module Promenade
  module Pitchfork
    class WorkerPidProvider
      def self.fetch
        worker_id || "process_id_#{Process.pid}"
      end

      def self.worker_id
        return unless defined?(::Pitchfork::Worker)

        ObjectSpace.each_object(::Pitchfork::Worker) do |worker|
          if worker.pid == Process.pid
            return "worker_id_#{worker.nr}"
          end
        end
      rescue StandardError
        nil
      end
    end
  end
end

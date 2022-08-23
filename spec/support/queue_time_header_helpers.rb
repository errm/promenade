module QueueTimeHeaderHelpers
  private

    def request_start_timestamp(time_obj = Time.now.utc)
      "t=#{time_obj.to_f.round(3)}"
    end
end

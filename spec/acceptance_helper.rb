require "spec_helper"
require "net/http"
require "uri"

SimpleCov.minimum_coverage 0

def get(url)
  Net::HTTP.get_response(URI(url))
end

def get_metric_value(metric)
  get("http://localhost:9394/metrics").body.each_line.detect do |line|
    if line.start_with?(metric)
      return line.delete_prefix(metric).to_f
    end
  end
  nil
end

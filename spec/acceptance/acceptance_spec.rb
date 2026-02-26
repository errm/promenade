require "spec_helper"
require "net/http"
require "uri"

RSpec.describe "promenade" do
  it "works correctly" do
    # Check that the metrics exporter is up
    expect(get("http://localhost:9394/metrics").code).to eq("200")

    # Check we have connection metrics for pitchfork and nginx listeners
    expect(get_metric_value('tcp_active_connections{listener="0.0.0.0:3000"}')).to eq(0)
    expect(get_metric_value('tcp_active_connections{listener="0.0.0.0:9292"}')).to eq(0)

    expect(get_metric_value('tcp_queued_connections{listener="0.0.0.0:3000"}')).to eq(0)
    expect(get_metric_value('tcp_queued_connections{listener="0.0.0.0:9292"}')).to eq(0)

    # Make a reuqest so initial value of all metrics is written
    get("http://localhost:3000/example")

    expect(get_metric_value('pitchfork_workers')).to eq(4)

    expect {
      10.times { get("http://localhost:3000/example") }
      sleep 0.1
    }.to change {
      get_metric_value('http_request_duration_seconds_bucket{code="200",controller_action="example#index",host="localhost",method="get",le="0.025"}')
    }.by(10)


    # Make some slow requests so we have some connection metrics to test
    10.times do
      Thread.new { get("http://localhost:3000/slow/2") }
    end

    # Wait for all the requests to start
    sleep 0.5

    expect(get_metric_value 'tcp_active_connections{listener="0.0.0.0:9292"}').to eq(4)
    expect(get_metric_value('tcp_queued_connections{listener="0.0.0.0:9292"}').to_i).to be >= 6
  end
end

def get(url)
  Net::HTTP.get_response(URI(url))
end

def get_metric_value(metric)
  get("http://localhost:9394/metrics").body.each_line.detect do |line|
    if line.start_with?(metric)
      return line.delete_prefix(metric).to_f
    end
  end
  return nil
end

require "acceptance_helper"

RSpec.describe "promenade" do
  it "works correctly", type: :acceptance do
    # Check that the metrics exporter is up
    expect(get("http://localhost:9394/metrics").code).to eq("200")

    # Check we have connection metrics for pitchfork and nginx listeners
    wait(5.seconds).for { get_metric_value('tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"}') }.not_to be_nil
    wait(5.seconds).for { get_metric_value('tcp_active_connections_peak{listener="0.0.0.0:9292",window="30s"}') }.not_to be_nil

    wait(5.seconds).for { get_metric_value('tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"}') }.not_to be_nil
    wait(5.seconds).for { get_metric_value('tcp_queued_connections_peak{listener="0.0.0.0:9292",window="30s"}') }.not_to be_nil

    # Make a request so initial value of all metrics is written
    get("http://localhost:3000/example")

    # pitchfork_workers is written in a rack.after_reply callback, after the response is sent
    wait(5.seconds).for { get_metric_value("pitchfork_workers") }.to eq(4)

    initial_request_count = get_metric_value('http_request_duration_seconds_bucket{code="200",controller_action="example#index",host="localhost",method="get",le="0.1"}')
    10.times { get("http://localhost:3000/example") }
    wait(5.seconds).for { get_metric_value('http_request_duration_seconds_bucket{code="200",controller_action="example#index",host="localhost",method="get",le="0.1"}') }.to eq(initial_request_count + 10)


    # Make some slow requests so we have some connection metrics to test
    10.times do
      Thread.new { get("http://localhost:3000/slow/2") }
    end

    wait(5.seconds).for { get_metric_value('tcp_active_connections_peak{listener="0.0.0.0:9292",window="30s"}') }.to eq(4)
    wait(5.seconds).for { get_metric_value('tcp_queued_connections_peak{listener="0.0.0.0:9292",window="30s"}').to_i }.to be >= 6
  end
end

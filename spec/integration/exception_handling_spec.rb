require "rails_helper"

RSpec.describe "Prometheus request tracking middleware", type: :request do
  it "counts the desired labels for successful requests" do
    histogram = ::Prometheus::Client.registry.get(:http_req_duration_seconds)
    response_duration = 1.0
    expected_labels = {
      code: "200",
      controller_action: "test_responses#success",
      host: "www.example.com",
      method: "get",
    }

    expect_any_instance_of(
      Promenade::Client::Rack::HTTPRequestDurationCollector,
    ).to receive(:current_time).and_return(1.0, 2.0)
    expect(histogram).to receive(:observe).
      with(expected_labels, response_duration)

    get "/success"
  end

  it "counts the expected labels for 5XX error requests" do
    histogram = ::Prometheus::Client.registry.get(:http_req_duration_seconds)
    response_duration = 1.0
    expected_labels = {
      code: "500",
      controller_action: "test_responses#server_error",
      host: "www.example.com",
      method: "get",
    }

    expect_any_instance_of(
      Promenade::Client::Rack::HTTPRequestDurationCollector,
    ).to receive(:current_time).and_return(1.0, 2.0)
    expect(histogram).to receive(:observe).
      with(expected_labels, response_duration)

    expect { get "/server-error" }.to raise_error(StandardError)
  end

  it "counts the expected labels for 4XX error requests" do
    histogram = ::Prometheus::Client.registry.get(:http_req_duration_seconds)
    response_duration = 1.0
    expected_labels = {
      code: "418",
      controller_action: "test_responses#client_error",
      host: "www.example.com",
      method: "get",
    }

    expect_any_instance_of(
      Promenade::Client::Rack::HTTPRequestDurationCollector,
    ).to receive(:current_time).and_return(1.0, 2.0)
    expect(histogram).to receive(:observe).
      with(expected_labels, response_duration)

    get "/client-error"
  end

  it "counts the expected labels for 404 error requests" do
    histogram = ::Prometheus::Client.registry.get(:http_req_duration_seconds)
    response_duration = 1.0
    expected_labels = {
      code: "404",
      controller_action: "test_responses#not_found",
      host: "www.example.com",
      method: "get",
    }

    expect_any_instance_of(
      Promenade::Client::Rack::HTTPRequestDurationCollector,
    ).to receive(:current_time).and_return(1.0, 2.0)
    expect(histogram).to receive(:observe).
      with(expected_labels, response_duration)

    expect { get "/not-found" }.to raise_error(ActionController::RoutingError)
  end

  it "uses the correct labels for error requests that are redirected" do
    histogram = ::Prometheus::Client.registry.get(:http_req_duration_seconds)
    response_duration = 1.0
    expected_labels = {
      code: "404",
      controller_action: "errors#not_found",
      host: "www.example.com",
      method: "get",
    }

    expect_any_instance_of(
      Promenade::Client::Rack::HTTPRequestDurationCollector,
    ).to receive(:current_time).and_return(1.0, 2.0)
    expect(histogram).to receive(:observe).
      with(expected_labels, response_duration)

    expect { get "/404" }.to raise_error(ActionController::RoutingError)
  end
end

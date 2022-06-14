require "rails_helper"

RSpec.describe "Show exceptions integration", type: :request do
  before do
    enable_show_exceptions
  end

  it "counts the expected labels for 400 error requests" do
    histogram = ::Prometheus::Client.registry.get(:http_req_duration_seconds)
    response_duration = 1.0
    expected_labels = {
      code: "400",
      controller_action: "test_responses#bad_request",
      host: "www.example.com",
      method: "get",
    }

    expect_any_instance_of(Promenade::Client::Rack::Collector).to receive(:current_time).and_return(1.0, 2.0)
    expect(histogram).to receive(:observe).with(expected_labels, response_duration)

    get "/bad-request"

    expect(response.status).to eq(400)
    expect(response.body).to eq("400 Bad requests Page\n")
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

    expect_any_instance_of(Promenade::Client::Rack::Collector).to receive(:current_time).and_return(1.0, 2.0)
    expect(histogram).to receive(:observe).with(expected_labels, response_duration)

    get "/server-error"

    expect(response.status).to eq(500)
    expect(response.body).to eq("500 Internal Server Error Page\n")
  end

  def enable_show_exceptions
    method = Rails.application.method(:env_config)
    expect(Rails.application).to receive(:env_config).with(no_args) do
      method.call.merge(
        'action_dispatch.show_exceptions' => true,
        'action_dispatch.show_detailed_exceptions' => false,
        'consider_all_requests_local' => false
      )
    end
  end
end

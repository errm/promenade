require "spec_helper"
require "promenade/client/rack/request_labeler"

RSpec.describe Promenade::Client::Rack::RequestLabeler, reset_prometheus_client: true do
  describe "#call" do
    it "sets the host from env HTTP_HOST" do
      env_hash = {
        "HTTP_HOST" => "test-host",
      }

      labels = described_class.call(env_hash)

      expect(labels).to include(host: "test-host")
    end

    it "sets the method from env REQUEST_METHOD" do
      env_hash = {
        "REQUEST_METHOD" => "test-method",
      }

      labels = described_class.call(env_hash)

      expect(labels).to include(method: "test-method")
    end

    it "converts the method to lower-case string" do
      env_hash = {
        "REQUEST_METHOD" => "TEST-METHOD",
      }

      labels = described_class.call(env_hash)

      expect(labels).to include(method: "test-method")
    end
  end
end

require "spec_helper"
require "promenade/client/rack/request_labeler"

RSpec.describe Promenade::Client::Rack::RequestLabeler, reset_prometheus_client: true do
  describe "#call" do
    it "sets the controller_action from action_dispatch.request.parameters" do
      env_hash = {
        "action_dispatch.request.parameters" => {
          "controller" => "test-controller",
          "action" => "test-action",
        },
      }

      labels = described_class.call(env_hash)

      expect(labels).to include(controller_action: "test-controller#test-action")
    end
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

    it "sets controller_action to unknown#:action if controller is not known" do
      env_hash = {
        "action_dispatch.request.parameters" => {
          "action" => "test-action",
        },
      }

      labels = described_class.call(env_hash)

      expect(labels).to include(controller_action: "unknown#test-action")
    end
    it "sets controller_action to :controller#unknown if action is not known" do
      env_hash = {
        "action_dispatch.request.parameters" => {
          "controller" => "test-controller",
        },
      }

      labels = described_class.call(env_hash)

      expect(labels).to include(controller_action: "test-controller#unknown")
    end
    it "sets controller_action to unknown#unknown if neither controller nor action is not known" do
      env_hash = {
        "action_dispatch.request.parameters" => Hash.new,
      }

      labels = described_class.call(env_hash)

      expect(labels).to include(controller_action: "unknown#unknown")
    end
  end
end

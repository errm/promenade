require "spec_helper"
require "promenade/client/rack/middleware_base"
require "rack/mock"
require "support/test_rack_app"

class Promenade::Client::Rack::TestMiddlewareSubclass < Promenade::Client::Rack::MiddlwareBase; end

RSpec.describe Promenade::Client::Rack::MiddlwareBase do
  describe "#call" do
    it "requires a subclass to define the trace method" do
      env = Rack::MockRequest.env_for
      app = TestRackApp.new
      middleware = Promenade::Client::Rack::TestMiddlewareSubclass.new(app, registry: double(:registry), label_builder: double(:label_builder))

      expect { middleware.call(env) }.to raise_error NotImplementedError, "Please define trace in Promenade::Client::Rack::TestMiddlewareSubclass"
    end
  end
end

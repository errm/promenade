class TestResponsesController < ApplicationController
  def success; end

  def server_error
    raise StandardError, "Server error 500"
  end

  def client_error
    render status: 418
  end

  def not_found
    raise ActionController::RoutingError,
      "No route matches [#{request.env['REQUEST_METHOD']}] #{request.env['PATH_INFO'].inspect}"
  end
end

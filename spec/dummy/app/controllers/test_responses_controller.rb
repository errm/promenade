class TestResponsesController < ApplicationController
  def success
  end

  def server_error
    raise StandardError, "Server error 500"
  end

  def client_error
    render status: 418
  end
end

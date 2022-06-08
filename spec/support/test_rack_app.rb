class TestRackApp
  attr_reader :status, :headers, :body

  def initialize(status: 200, headers: {}, body: "It works!")
    @status = status
    @headers = headers
    @body = body
  end

  def call(env)
    [status, headers, body]
  end
end

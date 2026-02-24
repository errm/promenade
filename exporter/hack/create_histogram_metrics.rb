require "promenade"

Promenade.setup

::Prometheus::Client.configure do |config|
  config.multiprocess_files_dir = "multiprocess/test_fixtures/histogram"
end

Promenade.histogram :calculator_time_taken do
  doc "Records how long it takes to do the adding"
  # promenade also has some bucket presets like :network and :memory for common usecases
  buckets [0.25, 0.5, 1, 2, 4]
end

Promenade.histogram :http_request_duration do
  doc "http request duration"
  # promenade also has some bucket presets like :network and :memory for common usecases
  buckets :network
end

Process.fork do
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 0.25)
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 0.5)
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 1)
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 2)
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 4)
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 5)
  Promenade.metric(:calculator_time_taken).observe({ operation: "subtract" }, 0.25)
  Promenade.metric(:calculator_time_taken).observe({ operation: "subtract" }, 0.5)
  Promenade.metric(:calculator_time_taken).observe({ operation: "subtract" }, 1)

  Promenade.metric(:http_request_duration).observe({ method: "GET" }, 1.2)
  Promenade.metric(:http_request_duration).observe({ method: "GET" }, 0.1)
  Promenade.metric(:http_request_duration).observe({ method: "GET" }, 0.01)
end

Process.fork do
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 2)
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 4)
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 5)
  Promenade.metric(:calculator_time_taken).observe({ operation: "subtract" }, 0.25)
  Promenade.metric(:calculator_time_taken).observe({ operation: "subtract" }, 0.5)
  Promenade.metric(:http_request_duration).observe({ method: "GET" }, 1.2)
  Promenade.metric(:http_request_duration).observe({ method: "GET" }, 0.1)
  Promenade.metric(:http_request_duration).observe({ method: "GET" }, 0.01)
end

Process.fork do
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 4)
  Promenade.metric(:calculator_time_taken).observe({ operation: "add" }, 5)
  Promenade.metric(:calculator_time_taken).observe({ operation: "subtract" }, 0.25)
  Promenade.metric(:calculator_time_taken).observe({ operation: "subtract" }, 1)
  Promenade.metric(:http_request_duration).observe({ method: "GET" }, 7)
  Promenade.metric(:http_request_duration).observe({ method: "GET" }, 1.2)
  Promenade.metric(:http_request_duration).observe({ method: "GET" }, 0.1)
end

Process.waitall

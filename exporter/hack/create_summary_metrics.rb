require "promenade"

Promenade.setup

Prometheus::Client.configure do |config|
  config.multiprocess_files_dir = "multiprocess/test_fixtures/summary"
end

Promenade.summary :api_client_http_timing do
  doc "record how long requests to the api are taking"
end

Process.fork do
  Promenade.metric(:api_client_http_timing).observe({ method: "get", path: "/api/v1/users" }, 0.5)
  Promenade.metric(:api_client_http_timing).observe({ method: "get", path: "/api/v1/users" }, 1)
end

Process.fork do
  Promenade.metric(:api_client_http_timing).observe({ method: "get", path: "/api/v1/users" }, 0.6)
  Promenade.metric(:api_client_http_timing).observe({ method: "get", path: "/api/v1/users" }, 2)
end

Process.fork do
  Promenade.metric(:api_client_http_timing).observe({ method: "get", path: "/api/v1/users" }, 0.7)
  Promenade.metric(:api_client_http_timing).observe({ method: "get", path: "/api/v1/users" }, 6)
end

Process.waitall

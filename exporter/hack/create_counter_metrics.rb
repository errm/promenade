require "promenade"

Promenade.setup

Prometheus::Client.configure do |config|
  config.multiprocess_files_dir = "multiprocess/test_fixtures/counter"
end

Promenade.counter :widgets_created_total do
  doc "Records how many widgets are created"
end

Process.fork do
  # Promenade.metric(:widgets_created_total).increment({}, 15)
  Promenade.metric(:widgets_created_total).increment({ type: "guinness" }, 150)
  Promenade.metric(:widgets_created_total).increment({ type: "murphys" }, 10)
end

Process.fork do
  # Promenade.metric(:widgets_created_total).increment({ type: "guinness" }, 50)
  Promenade.metric(:widgets_created_total).increment({ type: "murphys" }, 51)
end

Process.fork do
  # Promenade.metric(:widgets_created_total).increment({}, 15)
  Promenade.metric(:widgets_created_total).increment({ type: "guinness" }, 100)
end

Process.waitall

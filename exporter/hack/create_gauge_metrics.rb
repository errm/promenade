require "promenade"

Promenade.setup

Prometheus::Client.configure do |config|
  config.multiprocess_files_dir = "multiprocess/test_fixtures/gauge"
end

Promenade.gauge :room_temperature_celsius do
  doc "Records room temprature"
  multiprocess_mode :max
end

Promenade.gauge :outside_temperature_celsius do
  doc "records outside temprature"
  multiprocess_mode :min
end

Promenade.gauge :oven_temperature_celsius do
  doc "records oven temprature"
  multiprocess_mode :liveall
end

Promenade.gauge :greenhouse_temperature_celsius do
  doc "records greenhouse temprature"
  multiprocess_mode :livesum
end

Promenade.gauge :water_temperature_celsius do
  doc "records water temprature"
  multiprocess_mode :all
end

Process.fork do
  Promenade.metric(:room_temperature_celsius).set({ room: "lounge" }, 22.3)
  Promenade.metric(:outside_temperature_celsius).set({ sensor: "garden" }, 11.1)
  Promenade.metric(:oven_temperature_celsius).set({ oven: "top" }, 150.1)
  Promenade.metric(:oven_temperature_celsius).set({ oven: "grill" }, 22)
  Promenade.metric(:greenhouse_temperature_celsius).set({ greenhouse: "inside" }, 27.1)
  Promenade.metric(:water_temperature_celsius).set({}, 32.1)
end

Process.fork do
  Promenade.metric(:room_temperature_celsius).set({ room: "lounge" }, 22.4)
  Promenade.metric(:room_temperature_celsius).set({ room: "broom_cupboard" }, 15.37)
  Promenade.metric(:oven_temperature_celsius).set({ oven: "top" }, 150.2)
  Promenade.metric(:greenhouse_temperature_celsius).set({ greenhouse: "inside" }, 27.2)
end

Process.fork do
  Promenade.metric(:room_temperature_celsius).set({ room: "kitchen" }, 25.45)
  Promenade.metric(:outside_temperature_celsius).set({ sensor: "garden" }, 10.9)
  Promenade.metric(:oven_temperature_celsius).set({ oven: "top" }, 155.2)
  Promenade.metric(:water_temperature_celsius).set({}, 33.1)
end

Process.waitall

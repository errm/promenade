# Promenade

[![CI](https://github.com/errm/promenade/actions/workflows/ci.yaml/badge.svg)](https://github.com/errm/promenade/actions/workflows/ci.yaml)
[![Gem Version](https://badge.fury.io/rb/promenade.svg)](https://badge.fury.io/rb/promenade)
[![codecov](https://codecov.io/github/errm/promenade/graph/badge.svg?token=Xreh8NR1nh)](https://codecov.io/github/errm/promenade)

Promenade is a library to simplify instrumenting Ruby applications with Prometheus.

## Usage

Add promenade to your Gemfile:

```ruby
gem "promenade"
```

### Built in instrumentation

Promenade includes built-in instrumentation for several libraries. Require the relevant file in an initializer to enable it.

```ruby
require "promenade/kafka"     # ruby-kafka
require "promenade/karafka"   # Karafka consumers
require "promenade/waterdrop"  # WaterDrop producers
```

### Instrumentation DSL

Promenade makes recording Prometheus metrics from your own code a little simpler with a DSL of sorts.

`Promenade` includes some methods for defining your own metrics, and a metric method you can use to record your metrics.

#### Counter

A counter is a metric that exposes a sum or tally of things.

```ruby
class WidgetService
  Promenade.counter :widgets_created do
    doc "Records how many widgets are created"
  end

  def create
    # Widget creation code :)
    Promenade.metric(:widgets_created).increment

    # You can also add extra labels as you set increment counters
    Promenade.metric(:widgets_created).increment({ type: "guinness" })
  end

  def batch_create
    # You can increment by more than 1 at a time if you need
    Promenade.metric(:widgets_created).increment({ type: "guinness" }, 100)
  end
end
```

#### Gauge

A gauge is a metric that exposes an instantaneous value or some snapshot of a changing value.

```ruby
class Thermometer
  Promenade.gauge :room_temperature_celsius do
    doc "Records room temprature"
  end

  def take_mesurements
    Promenade.metric(:room_temperature_celsius).set({ room: "lounge" }, 22.3)
    Promenade.metric(:room_temperature_celsius).set({ room: "kitchen" }, 25.45)
    Promenade.metric(:room_temperature_celsius).set({ room: "broom_cupboard" }, 15.37)
  end
end
```

#### Histogram

A histogram samples observations (usually things like request durations or
response sizes) and counts them in configurable buckets. It also provides a sum
of all observed values.

```ruby
class Calculator
  Promenade.histogram :calculator_time_taken do
    doc "Records how long it takes to do the adding"
    # promenade also has some bucket presets like :network and :memory for common use cases
    buckets [0.25, 0.5, 1, 2, 4]
  end

  def add_up
    timing = Benchmark.realtime do
      # Some time consuming addition
    end

    Promenade.metric(:calculator_time_taken).observe({ operation: "addition"}, timing)
  end
end
```

#### Summary

Summary is similar to a histogram, but for when you just care about percentile values. Often useful for timings.

```ruby
class ApiClient
  Promenade.summary :api_client_http_timing do
    doc "record how long requests to the api are taking"
  end

  def get_users
    timing = Benchmark.realtime do
      # Makes a network call
    end

    Promenade.metric(:api_client_http_timing).observe({ method: "get", path: "/api/v1/users" }, timing)
  end
end
```

### Exporter

The recommended way to expose metrics is the **Go exporter sidecar** in [`exporter/`](exporter/). It runs as a separate container that reads the `.db` files written by the Ruby application and exposes them at `:9394/metrics`. This keeps scrape overhead entirely off the Ruby application process and also collects TCP connection metrics (busy/queued workers) via Linux netlink without any native extension.

The exporter sidecar shares a network namespace and tmpfs volume with your app container. See [`compose.yml`](compose.yml) for a reference deployment:

```yaml
services:
  app:
    # your Ruby app; writes metrics to tmp/promenade on the shared tmpfs
    volumes:
      - tmp:/app/tmp
    environment:
      PROMETHEUS_MULTIPROC_DIR: /app/tmp/promenade
  exporter:
    image: ghcr.io/errm/promenade:latest
    network_mode: service:app   # shares the app's network namespace
    volumes:
      - tmp:/app/tmp
volumes:
  tmp:
    driver: local
    driver_opts:
      type: tmpfs
      device: tmpfs
```

The exporter is configured with `--multiprocess-dir` (or `PROMETHEUS_MULTIPROC_DIR`) and `--metrics-port` (default `9394`).


### Rails Middleware

Promenade provides custom Rack middleware to track HTTP response times for requests in your Rails application.

This was originally inspired by [prometheus-client-mmap](https://gitlab.com/gitlab-org/prometheus-client-mmap/-/blob/master/lib/prometheus/client/rack/collector.rb).

**The following middleware is automatically added to your Rack stack if your application is a Ruby on Rails app:**

- `Promenade::Client::Rack::HTTPRequestQueueTimeCollector` — inserted at the front of the stack, records time spent in the request queue (via `X-Request-Start` / `X-Queue-Start` headers).
- `Promenade::Client::Rack::HTTPRequestDurationCollector` — inserted after `ActionDispatch::ShowExceptions`, records response duration and HTTP exception counts.
- `Promenade::YJIT::Middleware` — appended, records YJIT stats (enabled only when `RubyVM::YJIT` is defined).
- `Promenade::Pitchfork::Middleware` — appended, records worker and memory metrics (enabled only when Pitchfork is present).

If you want to change the position of `HTTPRequestDurationCollector`, or customise its labels and exception handling behaviour, simply remove it from the stack and re-insert it with your own preferences.

``` ruby
Rails.application.middleware.delete(Promenade::Client::Rack::HTTPRequestDurationCollector)
Rails.application.middleware.insert_after(Rails::Rack::Logger, Promenade::Client::Rack::HTTPRequestDurationCollector)
```

#### Customising the labels recorded for each request

If you would like to collect different labels with each request, you may do so by customising the middleware installation:

``` ruby
label_builder = Proc.new do |env|
  {
    method: env["REQUEST_METHOD"].to_s.downcase,
    host: env["HTTP_HOST"].to_s,
    controller: env.dig("action_dispatch.request.parameters", "controller") || "unknown",
    action: env.dig("action_dispatch.request.parameters", "action") || "unknown"
  }
end
Rails.application.config.middleware.insert_after ActionDispatch::ShowExceptions,
        Promenade::Client::Rack::HTTPRequestDurationCollector,
        label_builder: label_builder
```

#### Customising how the middleware handles exceptions

The default implementation will capture exceptions, count the exception class name (e.g. `"StandardError"`), and then re-raise the exception.

If you would like to customise this behaviour, you may do so by customising the middleware installation:

``` ruby
exception_handler = Proc.new do |exception, env_hash, duration|
  # This simple example just re-raises the exception
  raise exception
end
Rails.application.config.middleware.insert_after ActionDispatch::ShowExceptions,
        Promenade::Client::Rack::HTTPRequestDurationCollector,
        exception_handler: exception_handler
```

#### Customising the histogram buckets

The default buckets cover a range of latencies from 5 ms to 10s see [Promenade::Configuration::DEFAULT_RACK_LATENCY_BUCKETS](https://github.com/errm/promenade/blob/master/lib/promenade/configuration.rb#L5) and [Promenade::Configuration::DEFAULT_QUEUE_TIME_BUCKETS](https://github.com/errm/promenade/blob/master/lib/promenade/configuration.rb#L7). This is intended to capture the typical range of latencies for a web application. However, this might not be suitable for your Service-Level Agreements (SLAs), and other bucket size intervals may be required (see [histogram bins](https://en.wikipedia.org/wiki/Histogram#Number_of_bins_and_width)).

If you would like to customise the histogram buckets, you can do so by configuring Promenade in an initializer:

```ruby
# config/initializers/promenade.rb

Promenade.configure do |config|
  config.rack_latency_buckets = [0.1, 0.25, 0.5, 1, 2.5, 5, 10]
  config.queue_time_buckets = [0.01, 0.5, 1.0, 10.0, 30.0]  # optional, for queue time collector
end
```

### Configuration

If you are using Rails it should load a railtie and configure promenade.

If you are not using Rails you should call `Promenade.setup` after your environment has loaded.

In a typical development environment there should be nothing for you to do. Promenade stores its state files in `tmp/promenade` and will create that directory if it does not exist.

In a production environment you should try to store the state files on tmpfs for performance, you can configure the path that promenade will write to by setting the `PROMETHEUS_MULTIPROC_DIR` environment variable.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/errm/promenade.

## Acknowledgements

The original code for the Rack middleware collector class was copied from [Prometheus Client MMap](https://gitlab.com/gitlab-org/prometheus-client-mmap/-/blob/master/lib/prometheus/client/rack/collector.rb).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

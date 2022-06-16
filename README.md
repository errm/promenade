# Promenade

[![CI](https://github.com/errm/promenade/actions/workflows/ci.yaml/badge.svg)](https://github.com/errm/promenade/actions/workflows/ci.yaml)
[![Gem Version](https://badge.fury.io/rb/promenade.svg)](https://badge.fury.io/rb/promenade)

Promenade is a library to simplify instrumenting Ruby applications with Prometheus.

It is currently under development.

## Usage

Add promenade to your Gemfle:

```
gem "promenade"
```

### Built in instrumentation

Promenade includes some built in instrumentation that can be used by requiring it (for example in an initializer).

Currently there is support for [ruby-kafka](https://github.com/zendesk/ruby-kafka), but I plan to support other things soon.

```
# Instrument the ruby-kafka libary
require "promenade/kafka"
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
    You can increment by more than 1 at a time if you need
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
    # promenade also has some bucket presets like :network and :memory for common usecases
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

Because promenade is based on prometheus-client you can add the `Prometheus::Client::Rack::Exporter` middleware to your rack middleware stack to expose metrics.

There is also a stand alone exporter that can be run with the `promenade` command.

This is ideal if you are worried about accidentally exposing your metrics, are concerned about the performance impact prometheus scrapes might have on your application, or for applications without a web server (like background processing jobs). It does mean that you have another process to manage on your server though 🤷.

The exporter runs by default on port `9394` and the metrics are available at the standard path of `/metrics`, the stand-alone exporter is configured to use gzip.


### Rails Middleware

Promenade provides custom Rack middleware to track HTTP response times for requests in your Rails application.

This was originally inspired by [prometheus-client-mmap](https://gitlab.com/gitlab-org/prometheus-client-mmap/-/blob/master/lib/prometheus/client/rack/collector.rb).

**This middleware is automatically added to your Rack stack if your application is a Ruby on Rails app.**

We recommend you add the middleware after `ActionDispatch::ShowExceptions` in your stack, so you can accurately record the controller and action where an exception was raised.

If you want to change the position, or customise the labels and exception handling behaviour, simply remove the middleware from the stack and re-insert it with your own preferences.

``` ruby
Rails.application.middleware.delete(Promenade::Client::Rack::Collector)
Rails.application.middleware.insert_after(Rails::Rack::Logger, Promenade::Client::Rack::Collector)
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
        Promenade::Client::Rack::Collector
        label_builder: label_builder
```

#### Customising how the middleware handles exceptions

The default implementation will capture exceptions, count the execption class name (e.g. `"StandardError"`), and then re-raise the exception.

If you would like to customise this behaviour, you may do so by customising the middleware installation:

``` ruby
exception_handler = Proc.new do |exception, exception_counter, env_hash, request_duration_seconds|
  # This simple example just re-raises the execption
  raise exception
end
Rails.application.config.middleware.insert_after ActionDispatch::ShowExceptions,
        Promenade::Client::Rack::Collector
        exception_handler: exception_handler
```

### Configuration

If you are using rails it should load a railtie and configure promenade.

If are not using rails you should call `Promenade.setup` after your environment has loaded.

In a typical development environment there should be nothing for you to do. Promenade stores its state files in `tmp/promenade` and will create that directory if it does not exist.

In a production environment you should try to store the state files on tmpfs for performance, you can configure the path that promenade will write to by setting the `PROMETHEUS_MULTIPROC_DIR` environment variable.

If you are running the stand-alone exporter, you may also set the `PORT` environment variable to bind to a port other than the default (`9394`).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/errm/promenade.

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Promenade project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/promenade/blob/master/CODE_OF_CONDUCT.md).

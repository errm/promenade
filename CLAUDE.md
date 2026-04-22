# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Promenade is a dual-component project for instrumenting Ruby applications with Prometheus metrics:

1. **Ruby Gem** (repo root): A DSL wrapper around `prometheus-client-mmap` for defining metrics in Ruby/Rails apps. Each Ruby worker writes metrics to `.db` files in a shared tmpfs directory (`tmp/promenade`).
2. **Go Exporter** (`exporter/`): A standalone Prometheus exporter that reads those `.db` files and exposes them at `:9394/metrics`. Also collects TCP connection metrics via Linux netlink.

In production, these run as three Docker containers (app, nginx, exporter) sharing a network namespace and a tmpfs volume (`compose.yml`).

## Commands

### Ruby Gem

```sh
bundle exec rake spec          # Run unit/integration tests
bundle exec rake rubocop       # Run linter
bundle exec rake               # Run everything (spec + rubocop + exporter + acceptance)
bundle exec rspec spec/path/to/spec.rb   # Run a single spec file
```

Acceptance tests require Docker: `bundle exec rake acceptance:spec`

### Go Exporter

```sh
cd exporter
go test -v ./...                                           # All tests
go test -v ./multiprocess -run TestCollector_Collect/gauge # Single test
go vet ./...                                               # Vet
golangci-lint run                                          # Lint
go build -o promenade .                                    # Build
```

## Architecture

### Go Exporter (`exporter/`)

- **`main.go`**: Parses flags (`--metrics-port`, `--multiprocess-dir` / `PROMETHEUS_MULTIPROC_DIR`), registers collectors, starts HTTP server.
- **`multiprocess/collector.go`**: Implements `prometheus.Collector` as an "unchecked collector" (empty `Describe`). Discovers `*.db` files at scrape time and parses the mmap binary format (8-byte header → records of `u32 length + JSON key + padding + f64 value`). Merges values across PIDs per metric type.
- **`tcpconnections/collector.go`**: Linux-only (`//go:build linux`). Uses netlink/SOCK_DIAG to count TCP connections per listener port. A no-op stub handles non-Linux builds.

**Test patterns**: Table-driven tests using `testutil.CollectAndCompare` and `testutil.CollectAndLint`. The `multiprocess` tests use real `.db` binary fixtures in `test_fixtures/`; regenerate them with the `hack/create_*.rb` Ruby scripts when the format changes. The `tcpconnections` tests inject a `mockNetlinkDumper` interface.

### Ruby Gem (`lib/`)

- **`lib/promenade.rb`**: Top-level DSL (`Promenade.counter`, `.gauge`, `.histogram`, `.summary`).
- **`lib/promenade/railtie.rb`**: Rails initializer — runs setup and inserts all middlewares.
- **`lib/promenade/client/rack/`**: Rack middlewares for request duration, queue time, and exception counting.
- **`lib/promenade/pitchfork/`**, **`lib/promenade/yjit/`**: Middlewares that use `rack.after_reply` to record Pitchfork worker/memory and YJIT stats *after* the response is sent.
- **`lib/promenade/kafka/`**, **`lib/promenade/karafka.rb`**, **`lib/promenade/waterdrop.rb`**: ActiveSupport::Subscriber-based Kafka instrumentation.

### Key Design Decisions

- **Gauge merge strategies**: The exporter replicates `prometheus-client-mmap` semantics — `:min`/`:max`/`:livesum` modes merge across PIDs; all other gauges keep PID as a label. Counters and histogram/summary values are always summed.
- **Unchecked collector**: `multiprocess.Collector.Describe` sends nothing — the metric set is discovered dynamically at scrape time.
- **Label injection**: `HTTPRequestDurationCollector` accepts a `label_builder:` proc, defaulting to `RequestControllerActionLabeler`. Swap it at construction time to change labeling without subclassing.
- **Static binary**: The production Docker image is a two-stage build producing a CGO static PIE binary (`-buildmode=pie`, `netgo`/`osusergo` tags) copied into a `scratch` image.

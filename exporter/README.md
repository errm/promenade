# promenade exporter

A Prometheus exporter for Ruby applications, written in Go.

## Why

Promenade is designed to minimise the impact of metrics collection on the Ruby application server. Running the exporter as a sidecar container means Prometheus scrapes never touch the Ruby process.

The exporter reads metrics files written directly by the Ruby application, so there is no in-process HTTP server needed on the Ruby side.

## Metrics

### Multiprocess metrics

Reads the mmap `.db` files written by `prometheus-client-mmap` from the shared `PROMETHEUS_MULTIPROC_DIR` directory and exposes them as standard Prometheus metrics.

### TCP connection metrics

Reports `tcp_active_connections_peak` and `tcp_queued_connections_peak` — the high-water mark number of active and queued connections for each listener port, sampled via Linux netlink (SOCK_DIAG) — the same data source as raindrops, but without any native Ruby extension.

Rather than sampling at scrape time, the exporter polls netlink frequently and tracks the peak value seen since the last bucket rotation. This avoids missing short-lived spikes that would be invisible to a single point-in-time sample.

A ring buffer of `window/1s + 1` buckets rotates every second. On each scrape the exporter returns the max across all buckets, guaranteeing a full window of lookback with at most 1s of inaccuracy at any rotation boundary. Multiple Prometheus instances in an HA setup see consistent values regardless of when they scrape.

## Configuration

All options can be set via flag or environment variable.

| Flag | Env var | Default | Description |
|---|---|---|---|
| `--metrics-port` | `PORT` | `9394` | Port to serve metrics on |
| `--multiprocess-dir` | `PROMETHEUS_MULTIPROC_DIR` | `/app/tmp/promenade` | Directory to read multiprocess metrics from |
| `--tcp-sampling-interval` | `TCP_SAMPLING_INTERVAL` | `25ms` | How often to poll netlink for TCP connection counts |
| `--tcp-hwm-window` | `TCP_HWM_WINDOW` | `30s` | High-water mark window; should match your Prometheus scrape interval |

## Deployment

The exporter runs as a sidecar container sharing a network namespace and tmpfs volume with the application container. See the [`compose.yml`](../compose.yml) at the root of this repo for a reference deployment.

## Development

### Running tests

The TCP connection tests use Linux kernel interfaces and must run on Linux. On macOS (or any non-Linux host), use:

```sh
make test
```

This runs the full test suite inside a Linux Docker container using the same Go version as the production image. Build and module caches are persisted in named Docker volumes so subsequent runs are fast.

On Linux you can run tests directly:

```sh
go test -v ./...
```

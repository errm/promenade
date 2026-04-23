# promenade exporter

A prometheus exporter for ruby applications (written in go)

# Why

Promenade was allways designed to minimise the impact of
metrics collection on the ruby application server.

Thus it was recomended to run a sidecar container (with a simple
server) to export metrics collected by the application server.

This takes this a step further, by reading metrics written by
the application server in a lightwight go based exporter.

# multiprocess metrics
* Reads multiprocess metrics written by prometheus-client-mmap
* Exposes them as prometheus metrics

# rack server metrics

* Reports the current number of in process connections (busy workers)
and connections that have not yet been processed (queing).
* Collects these metrics via netlink / diag like raindrops, but
without any need for the ruby native extension.
* Implimentation details are significantly simpler than raindrops, due to robust
and easy to use libaries for dealing with netlink and socket statistics.
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

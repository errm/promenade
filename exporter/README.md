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

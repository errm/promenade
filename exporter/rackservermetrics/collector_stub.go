//go:build !linux
// +build !linux

package rackservermetrics

import (
	"github.com/prometheus/client_golang/prometheus"
)

// Collector collects metrics about requests in progress and queuing for a Ruby application server.
// On non-Linux platforms, this is a stub that does nothing.
type Collector struct{}

// NewCollector creates a new Collector. On non-Linux platforms, this returns a stub collector.
func NewCollector() (*Collector, error) {
	return &Collector{}, nil
}

// Describe implements prometheus.Collector. On non-Linux platforms, this does nothing.
func (c *Collector) Describe(ch chan<- *prometheus.Desc) {
	// Stub: no-op on non-Linux platforms
}

// Collect implements prometheus.Collector. On non-Linux platforms, this does nothing.
func (c *Collector) Collect(ch chan<- prometheus.Metric) {
	// Stub: no-op on non-Linux platforms
}

// Close closes the collector. On non-Linux platforms, this does nothing.
func (c *Collector) Close() error {
	// Stub: no-op on non-Linux platforms
	return nil
}

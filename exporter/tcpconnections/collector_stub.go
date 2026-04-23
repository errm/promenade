//go:build !linux
// +build !linux

package tcpconnections

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

// Collector is a no-op stub for non-Linux platforms.
type Collector struct{}

// NewCollector returns a stub collector. The interval and window parameters
// are accepted to match the Linux implementation but are ignored.
func NewCollector(interval, window time.Duration) (*Collector, error) {
	return &Collector{}, nil
}

// Describe implements prometheus.Collector.
func (c *Collector) Describe(ch chan<- *prometheus.Desc) {}

// Collect implements prometheus.Collector.
func (c *Collector) Collect(ch chan<- prometheus.Metric) {}

// Close implements io.Closer.
func (c *Collector) Close() error { return nil }

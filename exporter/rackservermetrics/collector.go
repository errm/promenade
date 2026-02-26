//go:build linux
// +build linux

package rackservermetrics

import (
	"fmt"
	"log"

	"github.com/florianl/go-diag"
	"github.com/prometheus/client_golang/prometheus"
	"golang.org/x/sys/unix"
)

// NetlinkDumper is an interface for dumping netlink socket information.
type NetlinkDumper interface {
	NetDump(opt *diag.NetOption) ([]diag.NetObject, error)
	Close() error
}

var (
	// Metric descriptors - created once and reused
	activeRequestsDesc = prometheus.NewDesc(
		"rack_active_requests",
		"Number of active requests in progress",
		[]string{"listener"},
		nil,
	)
	queuedRequestsDesc = prometheus.NewDesc(
		"rack_queued_requests",
		"Number of requests in queue",
		[]string{"listener"},
		nil,
	)
)

// Collector collects metrics about requests in progress and queuing.
type Collector struct {
	netlink NetlinkDumper
}

// listenerMetrics holds the active and queued request counts for a listener.
type listenerMetrics struct {
	address string
	port    uint16
	active  int
	queued  int
}

// NewCollector creates a new Collector with a real netlink connection.
func NewCollector() (*Collector, error) {
	nl, err := diag.Open(&diag.Config{})
	if err != nil {
		return nil, fmt.Errorf("could not open netlink socket: %w", err)
	}
	return &Collector{
		netlink: nl,
	}, nil
}

// Describe implements prometheus.Collector.
func (c *Collector) Describe(ch chan<- *prometheus.Desc) {
	ch <- activeRequestsDesc
	ch <- queuedRequestsDesc
}

// Collect implements prometheus.Collector.
func (c *Collector) Collect(ch chan<- prometheus.Metric) {
	listenerMetrics, err := c.collectMetrics()
	if err != nil {
		log.Println(err)
		// If collection fails, we don't send any metrics
		return
	}

	// Emit metrics for each listener
	for _, metrics := range listenerMetrics {
		listener := fmt.Sprintf("%s:%d", metrics.address, metrics.port)
		ch <- prometheus.MustNewConstMetric(
			activeRequestsDesc,
			prometheus.GaugeValue,
			float64(metrics.active),
			listener,
		)
		ch <- prometheus.MustNewConstMetric(
			queuedRequestsDesc,
			prometheus.GaugeValue,
			float64(metrics.queued),
			listener,
		)
	}
}

// getSocketStats queries netlink for sockets in the given state.
func (c *Collector) getSocketStats(state uint8) ([]diag.NetObject, error) {
	opt := &diag.NetOption{
		Family:   unix.AF_INET,
		Protocol: unix.IPPROTO_TCP,
		State:    (1 << state),
	}
	objs, err := c.netlink.NetDump(opt)
	if err != nil {
		return nil, fmt.Errorf("could not dump netlink data for state %d: %w", state, err)
	}
	return objs, nil
}

// collectMetrics collects the socket metrics from netlink.
func (c *Collector) collectMetrics() ([]listenerMetrics, error) {
	// First pass: query sockets in the TCP_LISTEN state to identify listeners
	var listeners []listenerMetrics

	listenObjs, err := c.getSocketStats(unix.BPF_TCP_LISTEN)
	if err != nil {
		return nil, fmt.Errorf("could not dump stats for listening sockets: %w", err)
	}

	// Initialize metrics for each listener
	for _, object := range listenObjs {
		ipAddr, err := diag.ToNetipAddrWithFamily(unix.AF_INET, object.ID.Src)
		if err != nil {
			continue
		}

		// Ignore Docker's internal DNS server
		if ipAddr.String() == "127.0.0.11" {
			continue
		}

		// Initialize metrics for this listener
		listeners = append(listeners, listenerMetrics{
			address: ipAddr.String(),
			port:    diag.Ntohs(object.ID.SPort),
			active:  0,
			queued:  0,
		})
	}

	// Second pass: get stats for sockets in the TCP_ESTABLISHED state and match to listeners
	establishedObjs, err := c.getSocketStats(unix.BPF_TCP_ESTABLISHED)
	if err != nil {
		return nil, fmt.Errorf("could not dump stats for established sockets: %w", err)
	}

	// Loop over established connections
	for _, object := range establishedObjs {
		// Match SPort to listener port
		sPort := diag.Ntohs(object.ID.SPort)

		// Find the listener with matching port
		var metrics *listenerMetrics
		for i := range listeners {
			if listeners[i].port == sPort {
				metrics = &listeners[i]
				break
			}
		}

		if metrics == nil {
			// Connection doesn't match any known listener, skip it
			continue
		}

		// Inode == 0 means the connection is in the queue
		if object.INode == 0 {
			metrics.queued++
		} else {
			metrics.active++
		}
	}

	return listeners, nil
}

// Close closes the netlink connection.
func (c *Collector) Close() error {
	if c.netlink != nil {
		return c.netlink.Close()
	}
	return nil
}

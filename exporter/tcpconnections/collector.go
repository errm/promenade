//go:build linux
// +build linux

package tcpconnections

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/florianl/go-diag"
	"github.com/prometheus/client_golang/prometheus"
	"golang.org/x/sys/unix"
)

// NetlinkDumper is an interface for dumping netlink socket information.
type NetlinkDumper interface {
	NetDump(opt *diag.NetOption) ([]diag.NetObject, error)
	Close() error
}

// listenerHWM holds the high-water mark active and queued connection counts for a listener.
type listenerHWM struct {
	active int
	queued int
}

// listenerMetrics holds the active and queued request counts sampled from netlink.
type listenerMetrics struct {
	address string
	port    uint16
	active  int
	queued  int
}

// Collector collects TCP connection metrics using a two-bucket high-water mark.
// A background goroutine samples netlink every interval and advances the current
// bucket upward. Every window/2 duration the bucket rotates: current becomes
// previous and a fresh current starts. Collect returns max(current, previous),
// making it safe for multiple Prometheus instances scraping at different times.
type Collector struct {
	netlink    NetlinkDumper
	interval   time.Duration
	window     time.Duration
	activeDesc *prometheus.Desc
	queuedDesc *prometheus.Desc
	mu         sync.Mutex
	current    map[string]listenerHWM
	previous   map[string]listenerHWM
	done       chan struct{}
	wg         sync.WaitGroup
	closeOnce  sync.Once
}

// NewCollector creates a new Collector and starts the background sampling loop.
// interval controls how often netlink is polled. window should match your
// Prometheus scrape interval; buckets rotate at window/2 internally so that
// any scrape always covers at least one full rotation period.
func NewCollector(interval, window time.Duration) (*Collector, error) {
	if interval <= 0 {
		return nil, fmt.Errorf("sampling interval must be positive, got %s", interval)
	}
	if window/2 <= 0 {
		return nil, fmt.Errorf("HWM window must be at least 2ns, got %s", window)
	}
	nl, err := diag.Open(&diag.Config{})
	if err != nil {
		return nil, fmt.Errorf("could not open netlink socket: %w", err)
	}
	c := &Collector{
		netlink:  nl,
		interval: interval,
		window:   window,
		activeDesc: prometheus.NewDesc(
			"tcp_active_connections_peak",
			fmt.Sprintf("Peak number of active TCP connections in the last %s", window),
			[]string{"listener"}, nil,
		),
		queuedDesc: prometheus.NewDesc(
			"tcp_queued_connections_peak",
			fmt.Sprintf("Peak number of queued TCP connections in the last %s", window),
			[]string{"listener"}, nil,
		),
		current:  make(map[string]listenerHWM),
		previous: make(map[string]listenerHWM),
		done:     make(chan struct{}),
	}
	c.wg.Add(1)
	go c.run()
	return c, nil
}

// run is the background goroutine that samples netlink and rotates buckets.
func (c *Collector) run() {
	defer c.wg.Done()
	if err := c.sample(); err != nil {
		log.Printf("TCP connection sampling error: %v", err)
	}
	sampleTicker := time.NewTicker(c.interval)
	rotateTicker := time.NewTicker(c.window / 2)
	defer sampleTicker.Stop()
	defer rotateTicker.Stop()
	var backoff time.Duration
	for {
		select {
		case <-c.done:
			return
		case <-sampleTicker.C:
			if err := c.sample(); err != nil {
				backoff = nextBackoff(backoff)
				log.Printf("TCP connection sampling error (retrying in %s): %v", backoff, err)
				select {
				case <-time.After(backoff):
				case <-rotateTicker.C:
					c.rotate()
				case <-c.done:
					return
				}
			} else if backoff > 0 {
				log.Println("TCP connection sampling recovered")
				backoff = 0
			}
		case <-rotateTicker.C:
			c.rotate()
		}
	}
}

// nextBackoff returns the next backoff duration, doubling from 1s up to 60s.
func nextBackoff(current time.Duration) time.Duration {
	const (
		initial = time.Second
		max     = 60 * time.Second
	)
	if current == 0 {
		return initial
	}
	if next := current * 2; next < max {
		return next
	}
	return max
}

// sample polls netlink and advances the current bucket high-water marks.
func (c *Collector) sample() error {
	metrics, err := c.collectMetrics()
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, m := range metrics {
		key := fmt.Sprintf("%s:%d", m.address, m.port)
		hwm := c.current[key]
		if m.active > hwm.active {
			hwm.active = m.active
		}
		if m.queued > hwm.queued {
			hwm.queued = m.queued
		}
		c.current[key] = hwm
	}
	return nil
}

// rotate moves the current bucket to previous and starts a fresh current bucket.
func (c *Collector) rotate() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.previous = c.current
	c.current = make(map[string]listenerHWM)
}

// Describe implements prometheus.Collector.
func (c *Collector) Describe(ch chan<- *prometheus.Desc) {
	ch <- c.activeDesc
	ch <- c.queuedDesc
}

// Collect implements prometheus.Collector. It returns max(current, previous)
// for each listener and does not reset state, so multiple scrapers see
// consistent values.
func (c *Collector) Collect(ch chan<- prometheus.Metric) {
	c.mu.Lock()
	merged := make(map[string]listenerHWM, len(c.current)+len(c.previous))
	for k, v := range c.previous {
		merged[k] = v
	}
	for k, v := range c.current {
		prev := merged[k]
		if v.active > prev.active {
			prev.active = v.active
		}
		if v.queued > prev.queued {
			prev.queued = v.queued
		}
		merged[k] = prev
	}
	c.mu.Unlock()

	for listener, hwm := range merged {
		ch <- prometheus.MustNewConstMetric(
			c.activeDesc,
			prometheus.GaugeValue,
			float64(hwm.active),
			listener,
		)
		ch <- prometheus.MustNewConstMetric(
			c.queuedDesc,
			prometheus.GaugeValue,
			float64(hwm.queued),
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
	listeners := make(map[uint16]*listenerMetrics)

	listenObjs, err := c.getSocketStats(unix.BPF_TCP_LISTEN)
	if err != nil {
		return nil, fmt.Errorf("could not dump stats for listening sockets: %w", err)
	}

	for _, object := range listenObjs {
		ipAddr, err := diag.ToNetipAddrWithFamily(unix.AF_INET, object.ID.Src)
		if err != nil {
			continue
		}
		if ipAddr.String() != "0.0.0.0" {
			continue
		}
		port := diag.Ntohs(object.ID.SPort)
		if _, exists := listeners[port]; exists {
			continue
		}
		listeners[port] = &listenerMetrics{address: "0.0.0.0", port: port}
	}

	establishedObjs, err := c.getSocketStats(unix.BPF_TCP_ESTABLISHED)
	if err != nil {
		return nil, fmt.Errorf("could not dump stats for established sockets: %w", err)
	}

	for _, object := range establishedObjs {
		sPort := diag.Ntohs(object.ID.SPort)
		metrics := listeners[sPort]
		if metrics == nil {
			continue
		}
		if object.INode == 0 {
			metrics.queued++
		} else {
			metrics.active++
		}
	}

	result := make([]listenerMetrics, 0, len(listeners))
	for _, m := range listeners {
		result = append(result, *m)
	}
	return result, nil
}

// Close stops the background sampling goroutine and closes the netlink connection.
// It is safe to call multiple times; subsequent calls are no-ops.
func (c *Collector) Close() error {
	var err error
	c.closeOnce.Do(func() {
		if c.done != nil {
			close(c.done)
			c.wg.Wait()
		}
		if c.netlink != nil {
			err = c.netlink.Close()
		}
	})
	return err
}

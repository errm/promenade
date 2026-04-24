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

var (
	activeDesc = prometheus.NewDesc(
		"tcp_active_connections_peak",
		"Peak number of active TCP connections in the configured high-water mark window.",
		[]string{"listener", "window"}, nil,
	)
	queuedDesc = prometheus.NewDesc(
		"tcp_queued_connections_peak",
		"Peak number of queued TCP connections in the configured high-water mark window.",
		[]string{"listener", "window"}, nil,
	)
)

// NetlinkDumper is an interface for dumping netlink socket information.
type NetlinkDumper interface {
	NetDump(opt *diag.NetOption) ([]diag.NetObject, error)
	Close() error
}

// connectionCounts holds the active and queued connection counts for a listener.
type connectionCounts struct {
	active int
	queued int
}

// rotationInterval is how often the ring buffer advances to a fresh bucket.
// Rotating every second means the reported peak can only be stale by at most 1s
// regardless of the configured window size.
const rotationInterval = time.Second

// Collector collects TCP connection metrics using a ring-buffer high-water mark.
// A background goroutine samples netlink every interval and advances the current
// bucket upward. Every second the ring advances: the oldest bucket is cleared and
// becomes the new current. The ring holds window/rotationInterval + 1 buckets so
// that Collect always returns a max spanning a full window, regardless of when the
// scrape falls relative to a rotation boundary. Consistent values for HA Prometheus
// setups are guaranteed because state is never reset on scrape.
type Collector struct {
	netlink   NetlinkDumper
	interval  time.Duration
	window    time.Duration
	mu        sync.Mutex
	buckets   []map[string]connectionCounts
	head      int // index of the current (most recent) bucket
	done      chan struct{}
	wg        sync.WaitGroup
	closeOnce sync.Once
}

// NewCollector creates a new Collector and starts the background sampling loop.
// interval controls how often netlink is polled. window should match your
// Prometheus scrape interval; the ring rotates every second so the reported
// peak is never more than 1s stale.
func NewCollector(interval, window time.Duration) (*Collector, error) {
	if interval <= 0 {
		return nil, fmt.Errorf("sampling interval must be positive, got %s", interval)
	}
	if window < rotationInterval {
		return nil, fmt.Errorf("HWM window must be at least %s, got %s", rotationInterval, window)
	}
	nl, err := diag.Open(&diag.Config{})
	if err != nil {
		return nil, fmt.Errorf("could not open netlink socket: %w", err)
	}
	numBuckets := int(window/rotationInterval) + 1
	c := &Collector{
		netlink:  nl,
		interval: interval,
		window:   window,
		buckets:  make([]map[string]connectionCounts, numBuckets),
		done:     make(chan struct{}),
	}
	for i := range c.buckets {
		c.buckets[i] = make(map[string]connectionCounts)
	}
	if err := c.sample(); err != nil {
		log.Printf("TCP connection sampling error: %v", err)
	}
	c.wg.Add(1)
	go c.run()
	return c, nil
}

// run is the background goroutine that samples netlink and rotates buckets.
func (c *Collector) run() {
	defer c.wg.Done()
	sampleTicker := time.NewTicker(c.interval)
	rotateTicker := time.NewTicker(rotationInterval)
	defer sampleTicker.Stop()
	defer rotateTicker.Stop()
	var backoff time.Duration
	var retryAfter time.Time
	for {
		select {
		case <-c.done:
			return
		case <-sampleTicker.C:
			if time.Now().Before(retryAfter) {
				continue
			}
			if err := c.sample(); err != nil {
				backoff = nextBackoff(backoff)
				retryAfter = time.Now().Add(backoff)
				log.Printf("TCP connection sampling error (retrying in %s): %v", backoff, err)
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
	if next := current * 2; next <= max {
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
	current := c.buckets[c.head]
	for key, m := range metrics {
		hwm := current[key]
		if m.active > hwm.active {
			hwm.active = m.active
		}
		if m.queued > hwm.queued {
			hwm.queued = m.queued
		}
		current[key] = hwm
	}
	return nil
}

// rotate advances the ring: the next slot is cleared and becomes the new current.
func (c *Collector) rotate() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.head = (c.head + 1) % len(c.buckets)
	c.buckets[c.head] = make(map[string]connectionCounts)
}

// Describe implements prometheus.Collector.
func (c *Collector) Describe(ch chan<- *prometheus.Desc) {
	ch <- activeDesc
	ch <- queuedDesc
}

// Collect implements prometheus.Collector. It returns the max across all buckets
// for each listener and does not reset state, so multiple scrapers see
// consistent values.
func (c *Collector) Collect(ch chan<- prometheus.Metric) {
	c.mu.Lock()
	merged := make(map[string]connectionCounts)
	for _, bucket := range c.buckets {
		for k, v := range bucket {
			m := merged[k]
			if v.active > m.active {
				m.active = v.active
			}
			if v.queued > m.queued {
				m.queued = v.queued
			}
			merged[k] = m
		}
	}
	c.mu.Unlock()

	window := c.window.String()
	for listener, hwm := range merged {
		ch <- prometheus.MustNewConstMetric(
			activeDesc,
			prometheus.GaugeValue,
			float64(hwm.active),
			listener, window,
		)
		ch <- prometheus.MustNewConstMetric(
			queuedDesc,
			prometheus.GaugeValue,
			float64(hwm.queued),
			listener, window,
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
func (c *Collector) collectMetrics() (map[string]connectionCounts, error) {
	listenObjs, err := c.getSocketStats(unix.BPF_TCP_LISTEN)
	if err != nil {
		return nil, fmt.Errorf("could not dump stats for listening sockets: %w", err)
	}

	// Build the set of wildcard listeners keyed by "address:port".
	// Use a port→key map to efficiently match established connections below.
	portKey := make(map[uint16]string)
	listeners := make(map[string]connectionCounts)
	for _, object := range listenObjs {
		ipAddr, err := diag.ToNetipAddrWithFamily(unix.AF_INET, object.ID.Src)
		if err != nil {
			continue
		}
		if ipAddr.String() != "0.0.0.0" {
			continue
		}
		port := diag.Ntohs(object.ID.SPort)
		if _, exists := portKey[port]; exists {
			continue
		}
		key := fmt.Sprintf("0.0.0.0:%d", port)
		portKey[port] = key
		listeners[key] = connectionCounts{}
	}

	establishedObjs, err := c.getSocketStats(unix.BPF_TCP_ESTABLISHED)
	if err != nil {
		return nil, fmt.Errorf("could not dump stats for established sockets: %w", err)
	}

	for _, object := range establishedObjs {
		key, ok := portKey[diag.Ntohs(object.ID.SPort)]
		if !ok {
			continue
		}
		hwm := listeners[key]
		// If the inode is zero, the connection is queued.
		if object.INode == 0 {
			hwm.queued++
		} else {
			hwm.active++
		}
		listeners[key] = hwm
	}

	return listeners, nil
}

// Close stops the background sampling goroutine and closes the netlink connection.
// It is safe to call multiple times; subsequent calls are no-ops.
func (c *Collector) Close() error {
	var err error
	c.closeOnce.Do(func() {
		close(c.done)
		c.wg.Wait()
		err = c.netlink.Close()
	})
	return err
}

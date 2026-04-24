//go:build linux
// +build linux

package tcpconnections

import (
	"net/netip"
	"strings"
	"testing"
	"time"

	"github.com/florianl/go-diag"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"golang.org/x/sys/unix"
)

const testWindow = 30 * time.Second

// newTestCollector builds a Collector with a mock netlink dumper and
// pre-initialised buckets, but without starting the background goroutine.
// Tests drive sampling and rotation directly via sample() and rotate().
func newTestCollector(mock *mockNetlinkDumper) *Collector {
	c := &Collector{
		netlink: mock,
		window:  testWindow,
	}
	for i := range c.buckets {
		c.buckets[i] = make(map[string]connectionCounts)
	}
	return c
}

// makeActive returns n active (non-zero inode) established connections on port.
func makeActive(port uint16, n int) []diag.NetObject {
	objs := make([]diag.NetObject, n)
	for i := range objs {
		objs[i] = makeNetObject("172.19.0.1", port, unix.BPF_TCP_ESTABLISHED, uint32(i+1))
	}
	return objs
}

// requireSample calls c.sample() and fails the test immediately if it errors.
func requireSample(t *testing.T, c *Collector) {
	t.Helper()
	if err := c.sample(); err != nil {
		t.Fatalf("unexpected sample error: %v", err)
	}
}

func TestCollector_Collect(t *testing.T) {
	tests := []struct {
		name               string
		listenObjects      []diag.NetObject
		establishedObjects []diag.NetObject
		expected           string
	}{
		{
			name: "idle listener",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			expected: `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`,
		},
		{
			name: "listener with active connections",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				makeNetObject("172.19.0.2", 3000, unix.BPF_TCP_ESTABLISHED, 12345),
				makeNetObject("172.19.0.3", 3000, unix.BPF_TCP_ESTABLISHED, 12346),
			},
			expected: `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 2
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`,
		},
		{
			name: "listener with queued connections",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				makeNetObject("172.19.0.2", 3000, unix.BPF_TCP_ESTABLISHED, 0),
				makeNetObject("172.19.0.3", 3000, unix.BPF_TCP_ESTABLISHED, 0),
			},
			expected: `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 2
`,
		},
		{
			name: "listener with mixed active and queued",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				makeNetObject("172.19.0.2", 3000, unix.BPF_TCP_ESTABLISHED, 12345),
				makeNetObject("172.19.0.3", 3000, unix.BPF_TCP_ESTABLISHED, 0),
				makeNetObject("172.19.0.4", 3000, unix.BPF_TCP_ESTABLISHED, 12346),
			},
			expected: `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 2
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 1
`,
		},
		{
			name: "multiple listeners",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
				makeNetObject("0.0.0.0", 8080, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				makeNetObject("172.19.0.2", 3000, unix.BPF_TCP_ESTABLISHED, 12345),
				makeNetObject("127.0.0.1", 8080, unix.BPF_TCP_ESTABLISHED, 12346),
			},
			expected: `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 1
tcp_active_connections_peak{listener="0.0.0.0:8080",window="30s"} 1
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
tcp_queued_connections_peak{listener="0.0.0.0:8080",window="30s"} 0
`,
		},
		{
			name: "ignores docker DNS",
			listenObjects: []diag.NetObject{
				makeNetObject("127.0.0.11", 53, unix.BPF_TCP_LISTEN, 0),
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			expected: `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`,
		},
		{
			name: "connection without matching listener is ignored",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				makeNetObject("172.19.0.2", 9999, unix.BPF_TCP_ESTABLISHED, 12345),
			},
			expected: `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`,
		},
		{
			name: "duplicate listeners from netlink are deduplicated",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				makeNetObject("172.19.0.2", 3000, unix.BPF_TCP_ESTABLISHED, 12345),
			},
			expected: `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 1
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mock := &mockNetlinkDumper{
				listenObjects:      tt.listenObjects,
				establishedObjects: tt.establishedObjects,
			}
			collector := newTestCollector(mock)
			requireSample(t, collector)

			if err := testutil.CollectAndCompare(collector, strings.NewReader(tt.expected)); err != nil {
				t.Errorf("CollectAndCompare failed: %v", err)
			}

			problems, err := testutil.CollectAndLint(collector)
			if err != nil {
				t.Errorf("CollectAndLint failed: %v", err)
			}
			if len(problems) > 0 {
				t.Errorf("CollectAndLint found %d problems:", len(problems))
				for _, problem := range problems {
					t.Errorf("  Problem: %v", problem)
				}
			}
		})
	}
}

func TestCollector_HWM(t *testing.T) {
	listener := []diag.NetObject{makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0)}

	t.Run("peak is reported across multiple samples", func(t *testing.T) {
		mock := &mockNetlinkDumper{listenObjects: listener}
		c := newTestCollector(mock)

		mock.establishedObjects = makeActive(3000, 5)
		requireSample(t, c)
		mock.establishedObjects = makeActive(3000, 3) // lower
		requireSample(t, c)
		mock.establishedObjects = makeActive(3000, 8) // new peak
		requireSample(t, c)
		mock.establishedObjects = makeActive(3000, 2) // lower again
		requireSample(t, c)

		expected := `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 8
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`
		if err := testutil.CollectAndCompare(c, strings.NewReader(expected)); err != nil {
			t.Errorf("CollectAndCompare failed: %v", err)
		}
	})

	t.Run("Collect is idempotent — no reset on scrape", func(t *testing.T) {
		mock := &mockNetlinkDumper{listenObjects: listener, establishedObjects: makeActive(3000, 5)}
		c := newTestCollector(mock)
		requireSample(t, c)

		expected := `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 5
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`
		if err := testutil.CollectAndCompare(c, strings.NewReader(expected)); err != nil {
			t.Errorf("first scrape failed: %v", err)
		}
		if err := testutil.CollectAndCompare(c, strings.NewReader(expected)); err != nil {
			t.Errorf("second scrape returned different values: %v", err)
		}
	})

	t.Run("peak persists across rotation into older buckets", func(t *testing.T) {
		mock := &mockNetlinkDumper{listenObjects: listener, establishedObjects: makeActive(3000, 10)}
		c := newTestCollector(mock)
		requireSample(t, c) // bucket[0]: active=10
		c.rotate()          // head→bucket[1] (empty); bucket[0] still holds active=10

		// No new samples yet — peak still visible in older bucket
		expected := `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 10
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`
		if err := testutil.CollectAndCompare(c, strings.NewReader(expected)); err != nil {
			t.Errorf("CollectAndCompare failed: %v", err)
		}

		// Second rotation: peak is now in the oldest bucket, still visible (full window guarantee)
		c.rotate()
		if err := testutil.CollectAndCompare(c, strings.NewReader(expected)); err != nil {
			t.Errorf("peak should still be visible after second rotation: %v", err)
		}
	})

	t.Run("peak clears after three rotations with no activity", func(t *testing.T) {
		mock := &mockNetlinkDumper{listenObjects: listener, establishedObjects: makeActive(3000, 10)}
		c := newTestCollector(mock)
		requireSample(t, c) // bucket[0]: active=10
		c.rotate()          // head→bucket[1] (empty)

		mock.establishedObjects = nil
		requireSample(t, c) // bucket[1]: active=0 (listener present, no connections)
		c.rotate()          // head→bucket[2] (empty); bucket[0] active=10 still in ring

		// Peak still visible in oldest bucket
		requireSample(t, c) // bucket[2]: active=0
		c.rotate()          // head→bucket[0], cleared; all buckets now active=0

		expected := `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`
		if err := testutil.CollectAndCompare(c, strings.NewReader(expected)); err != nil {
			t.Errorf("CollectAndCompare failed: %v", err)
		}
	})

	t.Run("disappeared listener still reported via older buckets", func(t *testing.T) {
		mock := &mockNetlinkDumper{listenObjects: listener, establishedObjects: makeActive(3000, 5)}
		c := newTestCollector(mock)
		requireSample(t, c) // bucket[0]: active=5
		c.rotate()          // head→bucket[1] (empty)

		// Listener disappears
		mock.listenObjects = nil
		mock.establishedObjects = nil
		requireSample(t, c) // bucket[1]: empty (no listeners in netlink)

		// Peak still visible in older bucket
		expected := `
# HELP tcp_active_connections_peak Peak number of active TCP connections in the configured high-water mark window.
# TYPE tcp_active_connections_peak gauge
tcp_active_connections_peak{listener="0.0.0.0:3000",window="30s"} 5
# HELP tcp_queued_connections_peak Peak number of queued TCP connections in the configured high-water mark window.
# TYPE tcp_queued_connections_peak gauge
tcp_queued_connections_peak{listener="0.0.0.0:3000",window="30s"} 0
`
		if err := testutil.CollectAndCompare(c, strings.NewReader(expected)); err != nil {
			t.Errorf("CollectAndCompare failed: %v", err)
		}

		// Second rotation: peak now in oldest bucket, still visible
		c.rotate()
		if err := testutil.CollectAndCompare(c, strings.NewReader(expected)); err != nil {
			t.Errorf("expected peak still visible after second rotation: %v", err)
		}

		// Third rotation: oldest bucket is cleared, listener fully gone
		c.rotate()
		if err := testutil.CollectAndCompare(c, strings.NewReader("")); err != nil {
			t.Errorf("expected no metrics after third rotation: %v", err)
		}
	})
}

func TestCollector_Close(t *testing.T) {
	mock := &mockNetlinkDumper{}
	collector := newTestCollector(mock)
	if err := collector.Close(); err != nil {
		t.Errorf("Close() error = %v, want nil", err)
	}
}

// mockNetlinkDumper is a mock implementation of NetlinkDumper for testing.
type mockNetlinkDumper struct {
	listenObjects      []diag.NetObject
	establishedObjects []diag.NetObject
	closeError         error
}

func (m *mockNetlinkDumper) NetDump(opt *diag.NetOption) ([]diag.NetObject, error) {
	if opt.State&(1<<unix.BPF_TCP_LISTEN) != 0 {
		return m.listenObjects, nil
	}
	if opt.State&(1<<unix.BPF_TCP_ESTABLISHED) != 0 {
		return m.establishedObjects, nil
	}
	return nil, nil
}

func (m *mockNetlinkDumper) Close() error {
	return m.closeError
}

// makeSockID builds a diag.SockID from a dotted-decimal IP and port.
func makeSockID(ipStr string, port uint16) diag.SockID {
	ip := netip.MustParseAddr(ipStr)
	ipBytes := ip.As4()

	// Convert IP bytes to uint32 in network byte order (big-endian).
	// The IP address is stored in the first uint32.
	ipUint32 := uint32(ipBytes[3])<<24 | uint32(ipBytes[2])<<16 | uint32(ipBytes[1])<<8 | uint32(ipBytes[0])

	var src [4]uint32
	src[0] = ipUint32 // IP address in first uint32; remaining uint32s are zero

	// Port needs to be in network byte order (big-endian).
	// diag.Ntohs converts FROM network byte order TO host byte order,
	// so we store it in network byte order by swapping the bytes.
	// e.g. port 3000 = 0x0BB8 becomes 0xB80B in network byte order.
	portNet := uint16((port&0xFF)<<8 | (port>>8)&0xFF) // swap bytes

	return diag.SockID{
		Src:   src,
		SPort: portNet,
	}
}

// makeNetObject creates a NetObject with the given IP, port, state, and inode.
func makeNetObject(ipStr string, port uint16, state uint8, inode uint32) diag.NetObject {
	return diag.NetObject{
		DiagMsg: diag.DiagMsg{
			ID:    makeSockID(ipStr, port),
			State: state,
			INode: inode,
		},
	}
}

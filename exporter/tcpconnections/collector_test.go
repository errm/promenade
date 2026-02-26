//go:build linux
// +build linux

package tcpconnections

import (
	"net/netip"
	"strings"
	"testing"

	"github.com/florianl/go-diag"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"golang.org/x/sys/unix"
)

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
# HELP tcp_active_connections Number of active connections
# TYPE tcp_active_connections gauge
tcp_active_connections{listener="0.0.0.0:3000"} 0
# HELP tcp_queued_connections Number of connections in queue
# TYPE tcp_queued_connections gauge
tcp_queued_connections{listener="0.0.0.0:3000"} 0
`,
		},
		{
			name: "listener with active connections",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				// Established connections have client IPs, but same port (matched by port)
				makeNetObject("172.19.0.2", 3000, unix.BPF_TCP_ESTABLISHED, 12345),
				makeNetObject("172.19.0.3", 3000, unix.BPF_TCP_ESTABLISHED, 12346),
			},
			expected: `
# HELP tcp_active_connections Number of active connections
# TYPE tcp_active_connections gauge
tcp_active_connections{listener="0.0.0.0:3000"} 2
# HELP tcp_queued_connections Number of connections in queue
# TYPE tcp_queued_connections gauge
tcp_queued_connections{listener="0.0.0.0:3000"} 0
`,
		},
		{
			name: "listener with queued connections",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				// Queued connections have client IPs, but same port (matched by port)
				makeNetObject("172.19.0.2", 3000, unix.BPF_TCP_ESTABLISHED, 0),
				makeNetObject("172.19.0.3", 3000, unix.BPF_TCP_ESTABLISHED, 0),
			},
			expected: `
# HELP tcp_active_connections Number of active connections
# TYPE tcp_active_connections gauge
tcp_active_connections{listener="0.0.0.0:3000"} 0
# HELP tcp_queued_connections Number of connections in queue
# TYPE tcp_queued_connections gauge
tcp_queued_connections{listener="0.0.0.0:3000"} 2
`,
		},
		{
			name: "listener with mixed active and queued",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				// Mixed connections with different client IPs, matched by port
				makeNetObject("172.19.0.2", 3000, unix.BPF_TCP_ESTABLISHED, 12345),
				makeNetObject("172.19.0.3", 3000, unix.BPF_TCP_ESTABLISHED, 0),
				makeNetObject("172.19.0.4", 3000, unix.BPF_TCP_ESTABLISHED, 12346),
			},
			expected: `
# HELP tcp_active_connections Number of active connections
# TYPE tcp_active_connections gauge
tcp_active_connections{listener="0.0.0.0:3000"} 2
# HELP tcp_queued_connections Number of connections in queue
# TYPE tcp_queued_connections gauge
tcp_queued_connections{listener="0.0.0.0:3000"} 1
`,
		},
		{
			name: "multiple listeners",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
				makeNetObject("127.0.0.1", 8080, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				// Connections matched by port, not IP
				makeNetObject("172.19.0.2", 3000, unix.BPF_TCP_ESTABLISHED, 12345),
				makeNetObject("172.19.0.3", 8080, unix.BPF_TCP_ESTABLISHED, 12346),
			},
			expected: `
# HELP tcp_active_connections Number of active connections
# TYPE tcp_active_connections gauge
tcp_active_connections{listener="0.0.0.0:3000"} 1
tcp_active_connections{listener="127.0.0.1:8080"} 1
# HELP tcp_queued_connections Number of connections in queue
# TYPE tcp_queued_connections gauge
tcp_queued_connections{listener="0.0.0.0:3000"} 0
tcp_queued_connections{listener="127.0.0.1:8080"} 0
`,
		},
		{
			name: "ignores docker DNS",
			listenObjects: []diag.NetObject{
				makeNetObject("127.0.0.11", 53, unix.BPF_TCP_LISTEN, 0),
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			expected: `
# HELP tcp_active_connections Number of active connections
# TYPE tcp_active_connections gauge
tcp_active_connections{listener="0.0.0.0:3000"} 0
# HELP tcp_queued_connections Number of connections in queue
# TYPE tcp_queued_connections gauge
tcp_queued_connections{listener="0.0.0.0:3000"} 0
`,
		},
		{
			name: "connection without matching listener is ignored",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			establishedObjects: []diag.NetObject{
				// Connection on different port, should be ignored
				makeNetObject("172.19.0.2", 9999, unix.BPF_TCP_ESTABLISHED, 12345),
			},
			expected: `
# HELP tcp_active_connections Number of active connections
# TYPE tcp_active_connections gauge
tcp_active_connections{listener="0.0.0.0:3000"} 0
# HELP tcp_queued_connections Number of connections in queue
# TYPE tcp_queued_connections gauge
tcp_queued_connections{listener="0.0.0.0:3000"} 0
`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mock := &mockNetlinkDumper{
				listenObjects:      tt.listenObjects,
				establishedObjects: tt.establishedObjects,
			}
			collector := &Collector{netlink: mock}

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

func TestCollector_Close(t *testing.T) {
	mock := &mockNetlinkDumper{
		closeError: nil,
	}
	collector := &Collector{netlink: mock}

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
	// Determine which state was requested
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

// Helper function to create a SockID with the given IP and port
func makeSockID(ipStr string, port uint16) diag.SockID {
	ip := netip.MustParseAddr(ipStr)
	ipBytes := ip.As4()

	// Convert IP bytes to uint32 in network byte order (big-endian)
	// The IP address is stored in the first uint32
	ipUint32 := uint32(ipBytes[3])<<24 | uint32(ipBytes[2])<<16 | uint32(ipBytes[1])<<8 | uint32(ipBytes[0])

	var src [4]uint32
	src[0] = ipUint32 // IP address in first uint32
	// Remaining uint32s are zero

	// Port needs to be in network byte order (big-endian)
	// diag.Ntohs converts FROM network byte order TO host byte order
	// So we store it in network byte order (big-endian)
	// On a little-endian system, this means swapping the bytes
	// Port 3000 = 0x0BB8, in network byte order = 0xB80B (bytes swapped)
	portNet := uint16((port&0xFF)<<8 | (port>>8)&0xFF) // Swap bytes

	return diag.SockID{
		Src:   src,
		SPort: portNet,
	}
}

// Helper function to create a NetObject
func makeNetObject(ipStr string, port uint16, state uint8, inode uint32) diag.NetObject {
	return diag.NetObject{
		DiagMsg: diag.DiagMsg{
			ID:    makeSockID(ipStr, port),
			State: state,
			INode: inode,
		},
	}
}

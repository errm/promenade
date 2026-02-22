//go:build linux
// +build linux

package rackservermetrics

import (
	"fmt"
	"net/netip"
	"testing"

	"github.com/florianl/go-diag"
	"github.com/prometheus/client_golang/prometheus"
	dto "github.com/prometheus/client_model/go"
	"golang.org/x/sys/unix"
)

type expectedMetricFamily struct {
	name    string
	metrics []expectedMetric
}

type expectedMetric struct {
	labels map[string]string
	value  float64
}

func TestCollector_Collect(t *testing.T) {
	tests := []struct {
		name               string
		listenObjects      []diag.NetObject
		establishedObjects []diag.NetObject
		wantMetrics        []expectedMetricFamily
	}{
		{
			name: "idle listener",
			listenObjects: []diag.NetObject{
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			wantMetrics: []expectedMetricFamily{
				{
					name: "rack_active_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 0},
					},
				},
				{
					name: "rack_queued_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 0},
					},
				},
			},
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
			wantMetrics: []expectedMetricFamily{
				{
					name: "rack_active_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 2},
					},
				},
				{
					name: "rack_queued_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 0},
					},
				},
			},
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
			wantMetrics: []expectedMetricFamily{
				{
					name: "rack_active_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 0},
					},
				},
				{
					name: "rack_queued_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 2},
					},
				},
			},
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
			wantMetrics: []expectedMetricFamily{
				{
					name: "rack_active_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 2},
					},
				},
				{
					name: "rack_queued_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 1},
					},
				},
			},
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
			wantMetrics: []expectedMetricFamily{
				{
					name: "rack_active_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 1},
						{labels: map[string]string{"listener": "127.0.0.1:8080"}, value: 1},
					},
				},
				{
					name: "rack_queued_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 0},
						{labels: map[string]string{"listener": "127.0.0.1:8080"}, value: 0},
					},
				},
			},
		},
		{
			name: "ignores docker DNS",
			listenObjects: []diag.NetObject{
				makeNetObject("127.0.0.11", 53, unix.BPF_TCP_LISTEN, 0),
				makeNetObject("0.0.0.0", 3000, unix.BPF_TCP_LISTEN, 0),
			},
			wantMetrics: []expectedMetricFamily{
				{
					name: "rack_active_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 0},
					},
				},
				{
					name: "rack_queued_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 0},
					},
				},
			},
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
			wantMetrics: []expectedMetricFamily{
				{
					name: "rack_active_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 0},
					},
				},
				{
					name: "rack_queued_requests",
					metrics: []expectedMetric{
						{labels: map[string]string{"listener": "0.0.0.0:3000"}, value: 0},
					},
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mock := &mockNetlinkDumper{
				listenObjects:      tt.listenObjects,
				establishedObjects: tt.establishedObjects,
			}
			collector := NewCollectorWithNetlink(mock)

			registry := prometheus.NewRegistry()
			registry.MustRegister(collector)

			metricFamilies, err := registry.Gather()
			if err != nil {
				t.Errorf("Unexpecred Gather() error = %v", err)
			}

			compareMetricFamilies(t, tt.wantMetrics, metricFamilies)
		})
	}
}

func TestCollector_Close(t *testing.T) {
	mock := &mockNetlinkDumper{
		closeError: nil,
	}
	collector := NewCollectorWithNetlink(mock)

	if err := collector.Close(); err != nil {
		t.Errorf("Close() error = %v, want nil", err)
	}
}

// compareMetricFamilies compares expected metric families with actual ones from the registry.
func compareMetricFamilies(t *testing.T, expected []expectedMetricFamily, actual []*dto.MetricFamily) {
	// Create a map of actual families by name for easy lookup
	actualMap := make(map[string]*dto.MetricFamily)
	for _, family := range actual {
		actualMap[family.GetName()] = family
	}

	// Check each expected family
	for _, expectedFamily := range expected {
		actualFamily, found := actualMap[expectedFamily.name]
		if !found {
			t.Errorf("Expected metric family %q not found in actual metrics", expectedFamily.name)
			continue
		}

		// Compare metrics within the family
		actualMetrics := actualFamily.GetMetric()
		if len(actualMetrics) != len(expectedFamily.metrics) {
			t.Errorf("Metric family %q: expected %d metrics, got %d", expectedFamily.name, len(expectedFamily.metrics), len(actualMetrics))
			continue
		}

		// Create a map of actual metrics by their label set for easy lookup
		actualMetricsMap := make(map[string]*dto.Metric)
		for _, metric := range actualMetrics {
			labelKey := labelsToKey(metric.GetLabel())
			actualMetricsMap[labelKey] = metric
		}

		// Check each expected metric
		for _, expectedMetric := range expectedFamily.metrics {
			labelKey := labelsMapToKey(expectedMetric.labels)
			actualMetric, found := actualMetricsMap[labelKey]
			if !found {
				t.Errorf("Metric family %q: expected metric with labels %v not found", expectedFamily.name, expectedMetric.labels)
				continue
			}

			// Compare the value
			actualValue := actualMetric.GetGauge().GetValue()
			if actualValue != expectedMetric.value {
				t.Errorf("Metric family %q with labels %v: expected value %f, got %f",
					expectedFamily.name, expectedMetric.labels, expectedMetric.value, actualValue)
			}
		}
	}

	// Check for unexpected metric families
	for _, actualFamily := range actual {
		found := false
		for _, expectedFamily := range expected {
			if actualFamily.GetName() == expectedFamily.name {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Unexpected metric family found: %q", actualFamily.GetName())
		}
	}
}

// labelsToKey converts a slice of LabelPair to a string key for comparison.
func labelsToKey(labels []*dto.LabelPair) string {
	key := ""
	for _, label := range labels {
		if key != "" {
			key += ","
		}
		key += fmt.Sprintf("%s=%s", label.GetName(), label.GetValue())
	}
	return key
}

// labelsMapToKey converts a map of labels to a string key for comparison.
func labelsMapToKey(labels map[string]string) string {
	key := ""
	first := true
	for k, v := range labels {
		if !first {
			key += ","
		}
		key += fmt.Sprintf("%s=%s", k, v)
		first = false
	}
	return key
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

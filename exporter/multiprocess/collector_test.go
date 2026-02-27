package multiprocess

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/prometheus/client_golang/prometheus/testutil"
)

func TestCollector_Collect(t *testing.T) {
	tests := []struct {
		name     string
		fixture  string
		expected string
	}{
		{
			name:    "counter",
			fixture: "counter",
			// Note that the fixture here includes a metric without labels
			// which is an invalid state that the ruby libary generating the
			// multiprocess files should usually prevent, but I want
			// to test that the collector can handle it
			expected: `
# HELP widgets_created_total Multiprocess metric
# TYPE widgets_created_total counter
widgets_created_total{type="guinness"} 250
widgets_created_total{type="murphys"} 61
widgets_created_total 30
`,
		},
		{
			name:    "gauge",
			fixture: "gauge",
			expected: `
# HELP greenhouse_temperature_celsius Multiprocess metric
# TYPE greenhouse_temperature_celsius gauge
greenhouse_temperature_celsius{greenhouse="inside"} 54.3
# HELP outside_temperature_celsius Multiprocess metric
# TYPE outside_temperature_celsius gauge
outside_temperature_celsius{sensor="garden"} 10.9
# HELP oven_temperature_celsius Multiprocess metric
# TYPE oven_temperature_celsius gauge
oven_temperature_celsius{oven="grill",pid="process_id_59891"} 22
oven_temperature_celsius{oven="top",pid="process_id_59891"} 150.1
oven_temperature_celsius{oven="top",pid="process_id_59892"} 150.2
oven_temperature_celsius{oven="top",pid="process_id_59893"} 155.2
# HELP room_temperature_celsius Multiprocess metric
# TYPE room_temperature_celsius gauge
room_temperature_celsius{room="broom_cupboard"} 15.37
room_temperature_celsius{room="kitchen"} 25.45
room_temperature_celsius{room="lounge"} 22.4
# HELP water_temperature_celsius Multiprocess metric
# TYPE water_temperature_celsius gauge
water_temperature_celsius{pid="process_id_59891"} 32.1
water_temperature_celsius{pid="process_id_59893"} 33.1
`,
		},
		{
			name:    "histogram",
			fixture: "histogram",
			expected: `
# HELP calculator_time_taken Multiprocess metric
# TYPE calculator_time_taken histogram
calculator_time_taken_bucket{le="0.25",operation="add"} 1
calculator_time_taken_bucket{le="0.25",operation="subtract"} 3
calculator_time_taken_bucket{le="0.5",operation="add"} 2
calculator_time_taken_bucket{le="0.5",operation="subtract"} 5
calculator_time_taken_bucket{le="1",operation="add"} 3
calculator_time_taken_bucket{le="1",operation="subtract"} 7
calculator_time_taken_bucket{le="2",operation="add"} 5
calculator_time_taken_bucket{le="2",operation="subtract"} 7
calculator_time_taken_bucket{le="4",operation="add"} 8
calculator_time_taken_bucket{le="4",operation="subtract"} 7
calculator_time_taken_bucket{le="+Inf",operation="add"} 11
calculator_time_taken_bucket{le="+Inf",operation="subtract"} 7
calculator_time_taken_count{operation="add"} 11
calculator_time_taken_count{operation="subtract"} 7
calculator_time_taken_sum{operation="add"} 32.75
calculator_time_taken_sum{operation="subtract"} 3.75
# HELP http_request_duration Multiprocess metric
# TYPE http_request_duration histogram
http_request_duration_bucket{le="0.005",method="GET"} 0
http_request_duration_bucket{le="0.01",method="GET"} 2
http_request_duration_bucket{le="0.025",method="GET"} 2
http_request_duration_bucket{le="0.05",method="GET"} 2
http_request_duration_bucket{le="0.1",method="GET"} 5
http_request_duration_bucket{le="0.25",method="GET"} 5
http_request_duration_bucket{le="0.5",method="GET"} 5
http_request_duration_bucket{le="1",method="GET"} 5
http_request_duration_bucket{le="2.5",method="GET"} 8
http_request_duration_bucket{le="5",method="GET"} 8
http_request_duration_bucket{le="10",method="GET"} 9
http_request_duration_bucket{le="+Inf",method="GET"} 9
http_request_duration_count{method="GET"} 9
http_request_duration_sum{method="GET"} 10.919999999999998
`,
		},
		{
			name:    "summary",
			fixture: "summary",
			expected: `
# HELP api_client_http_timing Multiprocess metric
# TYPE api_client_http_timing summary
api_client_http_timing_count{method="get",path="/api/v1/users"} 6
api_client_http_timing_sum{method="get",path="/api/v1/users"} 10.8
`,
		},
		{
			name:    "all",
			fixture: "*",
			expected: `
# HELP api_client_http_timing Multiprocess metric
# TYPE api_client_http_timing summary
api_client_http_timing_count{method="get",path="/api/v1/users"} 6
api_client_http_timing_sum{method="get",path="/api/v1/users"} 10.8
# HELP calculator_time_taken Multiprocess metric
# TYPE calculator_time_taken histogram
calculator_time_taken_bucket{le="0.25",operation="add"} 1
calculator_time_taken_bucket{le="0.25",operation="subtract"} 3
calculator_time_taken_bucket{le="0.5",operation="add"} 2
calculator_time_taken_bucket{le="0.5",operation="subtract"} 5
calculator_time_taken_bucket{le="1",operation="add"} 3
calculator_time_taken_bucket{le="1",operation="subtract"} 7
calculator_time_taken_bucket{le="2",operation="add"} 5
calculator_time_taken_bucket{le="2",operation="subtract"} 7
calculator_time_taken_bucket{le="4",operation="add"} 8
calculator_time_taken_bucket{le="4",operation="subtract"} 7
calculator_time_taken_bucket{le="+Inf",operation="add"} 11
calculator_time_taken_bucket{le="+Inf",operation="subtract"} 7
calculator_time_taken_count{operation="add"} 11
calculator_time_taken_count{operation="subtract"} 7
calculator_time_taken_sum{operation="add"} 32.75
calculator_time_taken_sum{operation="subtract"} 3.75
# HELP greenhouse_temperature_celsius Multiprocess metric
# TYPE greenhouse_temperature_celsius gauge
greenhouse_temperature_celsius{greenhouse="inside"} 54.3
# HELP http_request_duration Multiprocess metric
# TYPE http_request_duration histogram
http_request_duration_bucket{le="0.005",method="GET"} 0
http_request_duration_bucket{le="0.01",method="GET"} 2
http_request_duration_bucket{le="0.025",method="GET"} 2
http_request_duration_bucket{le="0.05",method="GET"} 2
http_request_duration_bucket{le="0.1",method="GET"} 5
http_request_duration_bucket{le="0.25",method="GET"} 5
http_request_duration_bucket{le="0.5",method="GET"} 5
http_request_duration_bucket{le="1",method="GET"} 5
http_request_duration_bucket{le="2.5",method="GET"} 8
http_request_duration_bucket{le="5",method="GET"} 8
http_request_duration_bucket{le="10",method="GET"} 9
http_request_duration_bucket{le="+Inf",method="GET"} 9
http_request_duration_count{method="GET"} 9
http_request_duration_sum{method="GET"} 10.919999999999998
# HELP outside_temperature_celsius Multiprocess metric
# TYPE outside_temperature_celsius gauge
outside_temperature_celsius{sensor="garden"} 10.9
# HELP oven_temperature_celsius Multiprocess metric
# TYPE oven_temperature_celsius gauge
oven_temperature_celsius{oven="grill",pid="process_id_59891"} 22
oven_temperature_celsius{oven="top",pid="process_id_59891"} 150.1
oven_temperature_celsius{oven="top",pid="process_id_59892"} 150.2
oven_temperature_celsius{oven="top",pid="process_id_59893"} 155.2
# HELP room_temperature_celsius Multiprocess metric
# TYPE room_temperature_celsius gauge
room_temperature_celsius{room="broom_cupboard"} 15.37
room_temperature_celsius{room="kitchen"} 25.45
room_temperature_celsius{room="lounge"} 22.4
# HELP water_temperature_celsius Multiprocess metric
# TYPE water_temperature_celsius gauge
water_temperature_celsius{pid="process_id_59891"} 32.1
water_temperature_celsius{pid="process_id_59893"} 33.1
# HELP widgets_created_total Multiprocess metric
# TYPE widgets_created_total counter
widgets_created_total 30
widgets_created_total{type="guinness"} 250
widgets_created_total{type="murphys"} 61
`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Get the path to the test fixtures
			fixtureDir := filepath.Join("test_fixtures", tt.fixture)

			// Create a collector pointing to the test fixtures
			collector := NewCollector(fixtureDir)

			// Use CollectAndCompare to compare collected metrics with expected output
			expectedReader := strings.NewReader(tt.expected)
			if err := testutil.CollectAndCompare(collector, expectedReader); err != nil {
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

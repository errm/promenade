package multiprocess

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"iter"
	"maps"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/prometheus/client_golang/prometheus"
)

const (
	headerSize = 8
)

// FileInfo contains metadata extracted from filename and file contents
type FileInfo struct {
	Path             string
	Type             string
	MultiprocessMode string
	PID              string
	Data             []byte
}

// Entry represents a parsed metric entry
type Entry struct {
	PID              string
	Type             string
	MultiprocessMode string
	Value            float64
	FamilyName       string
	MetricName       string
	labels           map[string]string
}

func (e Entry) Labels() prometheus.Labels {
	labels := make(prometheus.Labels)
	for k, v := range e.labels {
		if k == "le" {
			continue
		}
		labels[k] = v
	}
	if e.isPIDSignificant() {
		labels["pid"] = e.PID
	}
	return labels
}

func (e Entry) upperBound() (float64, error) {
	if le, ok := e.labels["le"]; ok {
		if le == "+Inf" {
			return math.Inf(1), nil
		}
		return strconv.ParseFloat(le, 64)
	}
	return 0, fmt.Errorf("no upper bound")
}

// isPIDSignificant determines if PID is exposed in labels
func (e Entry) isPIDSignificant() bool {
	return e.PID != "" &&
		e.Type == "gauge" &&
		e.MultiprocessMode != "min" &&
		e.MultiprocessMode != "max" &&
		e.MultiprocessMode != "livesum"
}

func (e Entry) mergeKey() string {
	parts := []string{e.FamilyName, e.MetricName}
	for k, v := range e.labels {
		parts = append(parts, fmt.Sprintf("%s=%s", k, v))
	}
	if e.isPIDSignificant() {
		parts = append(parts, fmt.Sprintf("pid=%s", e.PID))
	}
	sort.Strings(parts)
	return strings.Join(parts, "|")
}

func (e Entry) groupKey() string {
	parts := []string{e.FamilyName}
	for k, v := range e.Labels() {
		parts = append(parts, fmt.Sprintf("%s=%s", k, v))
	}
	sort.Strings(parts)
	return strings.Join(parts, "|")
}

// Collector implements prometheus.Collector to read metrics from .db files
type Collector struct {
	dir string
}

// NewCollector creates a new collector that discovers .db files in the given directory
func NewCollector(dir string) *Collector {
	return &Collector{dir: dir}
}

// Describe implements prometheus.Collector
func (c *Collector) Describe(ch chan<- *prometheus.Desc) {
	// We want this collector to be unchecked as we have no idea what metrics
	// we might be exposing before reading all the files - and this might change over time
	// as metrics are written by the ruby application.
}

// Collect implements prometheus.Collector
func (c *Collector) Collect(ch chan<- prometheus.Metric) {
	// Discover all .db files in the directory
	files, err := filepath.Glob(filepath.Join(c.dir, "*.db"))
	if err != nil {
		// If directory doesn't exist or can't be read, return silently
		// This allows the collector to work even if the directory is created later
		return
	}

	// Parse all files and collect entries
	var allEntries []Entry
	for _, filepath := range files {
		info, err := parseFileInfo(filepath)
		if err != nil {
			continue // Skip files that can't be read
		}

		entries, err := parseEntries(info)
		if err != nil {
			continue // Skip files that can't be parsed
		}

		allEntries = append(allEntries, entries...)
	}

	// Merge entries
	merged := mergeEntries(allEntries)
	grouped := groupEntries(merged)

	// Convert entries to Prometheus metrics
	for entry := range grouped {
		metric, err := entriesToMetric(entry)
		if err != nil {
			continue // Skip invalid entries
		}
		ch <- metric
	}
}

func groupEntries(entries iter.Seq[Entry]) iter.Seq[[]Entry] {
	groups := make(map[string][]Entry)
	for entry := range entries {
		groups[entry.groupKey()] = append(groups[entry.groupKey()], entry)
	}
	return maps.Values(groups)
}

// entriesToHistogram converts histogram entries (buckets, count, sum) to a single histogram metric
func entriesToHistogram(entries []Entry) (prometheus.Metric, error) {
	if len(entries) == 0 {
		return nil, fmt.Errorf("no entries provided")
	}

	var count, sum float64
	buckets := make(map[float64]uint64)

	for _, entry := range entries {
		if strings.HasSuffix(entry.MetricName, "_bucket") {
			upperBound, err := entry.upperBound()
			if err != nil {
				return nil, err
			}
			buckets[upperBound] = uint64(entry.Value)
		} else if strings.HasSuffix(entry.MetricName, "_count") {
			count = entry.Value
		} else if strings.HasSuffix(entry.MetricName, "_sum") {
			sum = entry.Value
		}
	}

	return prometheus.NewConstHistogram(
		prometheus.NewDesc(
			entries[0].FamilyName,
			"Multiprocess metric",
			nil,
			entries[0].Labels(),
		),
		uint64(count),
		sum,
		buckets,
	)
}

// entriesToSummary converts summary entries (count, sum) to a single summary metric
func entriesToSummary(entries []Entry) (prometheus.Metric, error) {
	if len(entries) == 0 {
		return nil, fmt.Errorf("no entries provided")
	}

	// Collect count and sum
	var count, sum float64

	for _, entry := range entries {
		// Process based on metric type
		if strings.HasSuffix(entry.MetricName, "_count") {
			count = entry.Value
		} else if strings.HasSuffix(entry.MetricName, "_sum") {
			sum = entry.Value
		}
	}

	return prometheus.NewConstSummary(
		prometheus.NewDesc(
			entries[0].FamilyName,
			"Multiprocess metric",
			nil,
			entries[0].Labels(),
		),
		uint64(count),
		sum,
		nil,
	)
}

func entriesToMetric(entries []Entry) (prometheus.Metric, error) {
	entry := entries[0]
	// Determine value type
	var valueType prometheus.ValueType
	switch entry.Type {
	case "counter":
		valueType = prometheus.CounterValue
	case "gauge":
		valueType = prometheus.GaugeValue
	case "histogram":
		return entriesToHistogram(entries)
	case "summary":
		return entriesToSummary(entries)
	default:
		valueType = prometheus.UntypedValue
	}

	return prometheus.NewConstMetric(
		prometheus.NewDesc(
			entry.MetricName,
			"Multiprocess metric",
			nil,
			entry.Labels(),
		),
		valueType,
		entry.Value,
	)
}

// parseFileInfo extracts metadata from filename and reads file contents
func parseFileInfo(path string) (*FileInfo, error) {
	basename := filepath.Base(path)
	name := strings.TrimSuffix(basename, ".db")

	parts := strings.Split(name, "_")
	if len(parts) < 2 {
		return nil, fmt.Errorf("invalid filename format: %s", basename)
	}

	// Remove trailing -number from parts
	for i, part := range parts {
		if idx := strings.LastIndex(part, "-"); idx > 0 {
			parts[i] = part[:idx]
		}
	}

	info := &FileInfo{
		Path:             path,
		Type:             parts[0],
		MultiprocessMode: parts[1],
	}

	if len(parts) > 2 {
		info.PID = strings.Join(parts[2:], "_")
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	info.Data = data
	return info, nil
}

// readU32 reads a little-endian u32 from the buffer
func readU32(buf []byte, offset int) (uint32, error) {
	if offset+4 > len(buf) {
		return 0, fmt.Errorf("out of bounds: offset %d, len %d", offset, len(buf))
	}
	return binary.LittleEndian.Uint32(buf[offset:]), nil
}

// readF64 reads a little-endian f64 from the buffer
func readF64(buf []byte, offset int) (float64, error) {
	if offset+8 > len(buf) {
		return 0, fmt.Errorf("out of bounds: offset %d, len %d", offset, len(buf))
	}
	bits := binary.LittleEndian.Uint64(buf[offset:])
	return math.Float64frombits(bits), nil
}

// paddingLen calculates padding to reach 8-byte alignment
func paddingLen(encodedLen int) int {
	return 8 - (4+encodedLen)%8
}

// parseEntries parses all entries from file data
func parseEntries(info *FileInfo) ([]Entry, error) {
	if len(info.Data) < headerSize {
		return nil, nil
	}

	used, err := readU32(info.Data, 0)
	if err != nil {
		return nil, err
	}

	if int(used) > len(info.Data) {
		return nil, fmt.Errorf("corrupted file: used %d > file size %d", used, len(info.Data))
	}

	var entries []Entry
	pos := headerSize

	for pos+4 < int(used) {
		encodedLen, err := readU32(info.Data, pos)
		if err != nil {
			return nil, err
		}

		pos += 4
		if pos+int(encodedLen) > len(info.Data) {
			return nil, fmt.Errorf("corrupted entry at pos %d", pos-4)
		}

		jsonStr := string(info.Data[pos : pos+int(encodedLen)])
		pos += int(encodedLen)

		padding := paddingLen(int(encodedLen))
		pos += padding

		if pos+8 > len(info.Data) {
			return nil, fmt.Errorf("corrupted value at pos %d", pos)
		}

		value, err := readF64(info.Data, pos)
		if err != nil {
			return nil, err
		}
		pos += 8

		// Parse JSON to extract familyName, metricName, and labels
		var parts []interface{}
		var familyName, metricName string
		labels := make(map[string]string)
		if err := json.Unmarshal([]byte(jsonStr), &parts); err == nil && len(parts) >= 4 {
			familyName, _ = parts[0].(string)
			metricName, _ = parts[1].(string)
			labelList, _ := parts[2].([]interface{})
			labelValues, _ := parts[3].([]interface{})
			for i, label := range labelList {
				if i < len(labelValues) {
					labelStr, _ := label.(string)
					value := labelValues[i]
					var valueStr string
					switch v := value.(type) {
					case string:
						valueStr = v
					case nil:
						valueStr = ""
					default:
						valueStr = fmt.Sprintf("%v", v)
					}
					labels[labelStr] = valueStr
				}
			}
		}

		entries = append(entries, Entry{
			PID:              info.PID,
			Type:             info.Type,
			MultiprocessMode: info.MultiprocessMode,
			Value:            value,
			FamilyName:       familyName,
			MetricName:       metricName,
			labels:           labels,
		})
	}

	return entries, nil
}

// mergeEntries merges entries with the same metric identity
func mergeEntries(allEntries []Entry) iter.Seq[Entry] {
	merged := make(map[string]Entry)

	for _, entry := range allEntries {
		if existing, ok := merged[entry.mergeKey()]; ok {
			// Merge values based on type and multiprocess mode
			if existing.Type == "gauge" {
				switch existing.MultiprocessMode {
				case "min":
					if entry.Value < existing.Value {
						existing.Value = entry.Value
					}
				case "max":
					if entry.Value > existing.Value {
						existing.Value = entry.Value
					}
				case "livesum":
					existing.Value += entry.Value
				default:
					existing.Value = entry.Value
				}
			} else {
				existing.Value += entry.Value
			}
			merged[entry.mergeKey()] = existing
		} else {
			merged[entry.mergeKey()] = entry
		}
	}

	return maps.Values(merged)
}

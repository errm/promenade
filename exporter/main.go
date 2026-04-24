package main

import (
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/alexflint/go-arg"

	"github.com/errm/promenade/exporter/multiprocess"
	"github.com/errm/promenade/exporter/tcpconnections"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type args struct {
	Port             int           `arg:"--metrics-port,env:PORT" help:"Port to serve metrics on" default:"9394"`
	MultiprocessDir  string        `arg:"--multiprocess-dir,env:PROMETHEUS_MULTIPROC_DIR" help:"Directory to read multiprocess metrics from" default:"/app/tmp/promenade"`
	SamplingInterval time.Duration `arg:"--tcp-sampling-interval,env:TCP_SAMPLING_INTERVAL" help:"How often to sample TCP connection metrics" default:"25ms"`
	HWMWindow        time.Duration `arg:"--tcp-hwm-window,env:TCP_HWM_WINDOW" help:"TCP high-water mark window; should match your Prometheus scrape interval" default:"30s"`
}

var cfg args

func init() {
	arg.MustParse(&cfg)
}

func main() {
	reg := prometheus.NewRegistry()

	serverMetricsCollector, err := tcpconnections.NewCollector(cfg.SamplingInterval, cfg.HWMWindow)
	if err != nil {
		log.Fatal(err)
	}

	reg.MustRegister(
		serverMetricsCollector,
		multiprocess.NewCollector(cfg.MultiprocessDir),
	)

	addr := ":" + strconv.Itoa(cfg.Port)
	log.Printf("Starting metrics server on %s", addr)
	http.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))
	serveErr := http.ListenAndServe(addr, nil)
	if closeErr := serverMetricsCollector.Close(); closeErr != nil {
		log.Println(closeErr)
	}
	log.Fatal(serveErr)
}

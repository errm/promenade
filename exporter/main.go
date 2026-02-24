package main

import (
	"log"
	"net/http"
	"strconv"

	"github.com/alexflint/go-arg"

	"github.com/errm/promenade/exporter/multiprocess"
	"github.com/errm/promenade/exporter/rackservermetrics"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type args struct {
	Port            int    `arg:"--metrics-port,env" help:"Port to serve metrics on" default:"9394"`
	MultiprocessDir string `arg:"--multiprocess-dir,env:PROMETHEUS_MULTIPROC_DIR" help:"Directory to read multiprocess metrics from" default:"/app/tmp/promenade"`
}

var cfg args

func init() {
	arg.MustParse(&cfg)
}

func main() {
	reg := prometheus.NewRegistry()

	serverMetricsCollector, err := rackservermetrics.NewCollector()
	if err != nil {
		log.Fatal(err)
	}
	defer serverMetricsCollector.Close()

	reg.MustRegister(
		serverMetricsCollector,
		multiprocess.NewCollector(cfg.MultiprocessDir),
	)

	addr := ":" + strconv.Itoa(cfg.Port)
	log.Printf("Starting metrics server on %s", addr)
	http.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))
	log.Fatal(http.ListenAndServe(addr, nil))
}

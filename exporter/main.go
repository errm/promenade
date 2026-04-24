package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
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
	srv := &http.Server{Addr: addr}
	http.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)

	go func() {
		log.Printf("Starting metrics server on %s", addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()

	<-quit
	log.Println("Shutting down")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("HTTP server shutdown error: %v", err)
	}
	if err := serverMetricsCollector.Close(); err != nil {
		log.Printf("Collector close error: %v", err)
	}
}

package main

import (
	"fmt"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"load_test/workerpool"

	"github.com/opentracing/opentracing-go"
	"github.com/prometheus/client_golang/prometheus"
	otbridge "go.opentelemetry.io/otel/bridge/opentracing"
	"go.opentelemetry.io/otel/exporters/jaeger"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.7.0"
)

var (
	concurrencyStr = os.Getenv("CONCURRENCY")
	spansCountStr  = os.Getenv("SPANS_COUNT")
	tagsCountStr   = os.Getenv("TAGS_COUNT")
	durationSStr   = os.Getenv("DURATION_S")

	concurrency = mustParseStrToInt(concurrencyStr, 50)
	spansCount  = mustParseStrToInt(spansCountStr, 10)
	tagsCount   = mustParseStrToInt(tagsCountStr, 10)
	durationS   = mustParseStrToInt(durationSStr, 60)

	// Create a new counter metric
	counter = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "send_spans",
		Help: "send traces to jaeger",
	})
)

func main() {
	prometheus.MustRegister(counter)

	http.Handle("/metrics", promhttp.Handler())
	go func() {
		// Start an HTTP server to expose the metrics
		err := http.ListenAndServe(":9101", nil)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to start metric server: %s", err)
			os.Exit(1)
		}
	}()

	timer := time.NewTimer(time.Second * time.Duration(durationS))
	pool := workerpool.New(workerpool.Config{
		PoolSize:        concurrency,
		TaskQueueLength: concurrency,
	})

	tracer := buildJaegerTracer()
	opentracing.SetGlobalTracer(tracer)

	for {
		select {
		case <-timer.C:
			pool.Close()
			// let prometheus scrape the metrics
			time.Sleep(time.Second * 30)
			return
		default:
		}

		pool.AddTask(func() {
			span := tracer.StartSpan("my-span")
			genTags(span)
			for i := 0; i < spansCount; i++ {
				childSpan := tracer.StartSpan("my-child-span", opentracing.ChildOf(span.Context()))
				genTags(childSpan)
				childSpan.Finish()
				counter.Inc()
			}
			span.Finish()
		})
	}
}

func buildJaegerTracer() opentracing.Tracer {
	exporter, err := jaeger.New(jaeger.WithCollectorEndpoint())
	if err != nil {
		panic(err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String("load_tests"),
		)),
	)

	otTracer, _ := otbridge.NewTracerPair(tp.Tracer(""))
	return otTracer

}

func genTags(span opentracing.Span) {
	for i := 0; i < tagsCount; i++ {
		span.SetTag(fmt.Sprintf("tag-%d", i), fmt.Sprintf("value-%d", i))
	}
}

func mustParseStrToInt(str string, defaultValue int) int {
	if str == "" {
		return defaultValue
	}
	atoi, err := strconv.Atoi(str)
	if err != nil {
		panic(err)
	}
	return atoi
}

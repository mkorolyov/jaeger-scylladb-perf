package load_tests

import (
	"fmt"
	"io"
	"os"
	"strconv"
	"time"

	"load_test/workerpool"

	"github.com/opentracing/opentracing-go"
	"github.com/uber/jaeger-client-go"
	jaegercfg "github.com/uber/jaeger-client-go/config"
	"github.com/uber/jaeger-client-go/transport"
)

var (
	concurrencyStr      = os.Getenv("CONCURRENCY")
	spansCountStr       = os.Getenv("SPANS_COUNT")
	tagsCountStr        = os.Getenv("TAGS_COUNT")
	durationSStr        = os.Getenv("DURATION_S")
	jaegerCollectorHost = os.Getenv("JAEGER_COLLECTOR_HOST")

	concurrency = mustParseStrToInt(concurrencyStr, 10)
	spansCount  = mustParseStrToInt(spansCountStr, 10)
	tagsCount   = mustParseStrToInt(tagsCountStr, 10)
	durationS   = mustParseStrToInt(durationSStr, 60)
)

func main() {
	if jaegerCollectorHost == "" {
		jaegerCollectorHost = "localhost"
	}

	timer := time.NewTimer(time.Second * time.Duration(durationS))
	pool := workerpool.New(workerpool.Config{
		PoolSize:        concurrency,
		TaskQueueLength: concurrency,
	})

	tracer, closer := buildJaegerTracer()
	opentracing.SetGlobalTracer(tracer)

	for {
		select {
		case <-timer.C:
			pool.Close()
			_ = closer.Close()
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
			}
			span.Finish()
		})
	}
}

func buildJaegerTracer() (opentracing.Tracer, io.Closer) {
	cfg := jaegercfg.Configuration{
		ServiceName: "my-service",
		Sampler: &jaegercfg.SamplerConfig{
			Type:  jaeger.SamplerTypeConst,
			Param: 1,
		},
		Reporter: &jaegercfg.ReporterConfig{
			CollectorEndpoint: fmt.Sprintf("http://%s:14268/api/traces", jaegerCollectorHost),
			LogSpans:          true,
		},
	}

	sender := transport.NewHTTPTransport(
		cfg.Reporter.CollectorEndpoint,
		transport.HTTPBatchSize(1),
	)

	reporter := jaeger.NewRemoteReporter(sender)

	tracer, closer, err := cfg.NewTracer(
		jaegercfg.Reporter(reporter),
	)
	if err != nil {
		panic(fmt.Sprintf("ERROR: cannot init Jaeger: %v\n", err))
	}
	return tracer, closer
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

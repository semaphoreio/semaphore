package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/echo"
)

var (
	versionFlag = flag.Bool("version", false, "print the server version and exit")
	nameFlag    = flag.String("name", "semaphore-echo", "implementation name advertised to MCP clients")
	httpAddr    = flag.String("http", ":3001", "address to serve the streamable MCP transport")
	version     = "0.1.0"
)

func main() {
	flag.Parse()

	if *versionFlag {
		fmt.Println(version)
		return
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	var ready atomic.Bool
	var healthy atomic.Bool

	srv := server.NewMCPServer(*nameFlag, version, server.WithToolCapabilities(true))
	echo.Register(srv)

	mux := http.NewServeMux()
	streamable := server.NewStreamableHTTPServer(
		srv,
		server.WithStreamableHTTPServer(&http.Server{
			Handler:           mux,
			ReadHeaderTimeout: 10 * time.Second,
		}),
	)

	mux.Handle("/mcp", streamable)
	mux.Handle("/mcp/", streamable)

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		if !healthy.Load() {
			http.Error(w, "unhealthy", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		if !ready.Load() {
			http.Error(w, "not ready", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	errCh := make(chan error, 1)
	ready.Store(true)
	healthy.Store(true)

	go func() {
		errCh <- streamable.Start(*httpAddr)
	}()

	log.Printf("mcp_server listening on %s (streamable HTTP)", *httpAddr)

	select {
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("streamable HTTP server failed: %v", err)
		}
	case <-ctx.Done():
		healthy.Store(false)
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := streamable.Shutdown(shutdownCtx); err != nil && !errors.Is(err, context.Canceled) {
			log.Printf("graceful shutdown encountered an error: %v", err)
		}

		if err := <-errCh; err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("streamable HTTP server closed with error: %v", err)
		}
	}
}

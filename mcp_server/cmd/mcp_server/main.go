package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/config"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/docs"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/jobs"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/organizations"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/pipelines"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/projects"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/workflows"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/watchman"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"
)

var (
	versionFlag      = flag.Bool("version", false, "print the server version and exit")
	nameFlag         = flag.String("name", "semaphore-mcp-server", "implementation name advertised to MCP clients")
	httpAddr         = flag.String("http", ":3001", "address to serve the streamable MCP transport")
	version          = "0.1.0"
	metricsNamespace = os.Getenv("METRICS_NAMESPACE")
)

const (
	metricService = "mcp-server"
)

func main() {
	watchman.Configure(fmt.Sprintf("%s.%s", metricService, metricsNamespace))

	flag.Parse()

	if *versionFlag {
		fmt.Println(version)
		return
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	var ready atomic.Bool
	var healthy atomic.Bool
	hooks := &server.Hooks{}
	configureHooks(hooks)

	srv := server.NewMCPServer(
		*nameFlag,
		version,
		server.WithToolCapabilities(true),
		server.WithHooks(hooks),
	)

	var (
		provider internalapi.Provider
		closeFn  func() error
	)

	bootstrapLog := logging.ForComponent("bootstrap")
	if strings.EqualFold(os.Getenv("MCP_USE_STUBS"), "true") {
		bootstrapLog.Info("using stubbed internal API clients (MCP_USE_STUBS=true)")
		config.SetDevMode(true)
		bootstrapLog.Info("dev mode enabled - skipping X-Semaphore-User-ID validation")
		provider = support.New()
	} else {
		cfg, err := internalapi.LoadConfig()
		if err != nil {
			bootstrapLog.WithError(err).Fatal("failed to load internal API configuration")
		}
		if err := cfg.Validate(); err != nil {
			bootstrapLog.WithError(err).Fatal("invalid internal API configuration")
		}

		manager, err := internalapi.NewManager(ctx, cfg)
		if err != nil {
			bootstrapLog.WithError(err).Fatal("failed to connect to internal APIs")
		}
		provider = manager
		closeFn = manager.Close
	}

	if closeFn != nil {
		defer func() {
			if err := closeFn(); err != nil {
				logging.ForComponent("internal_api").WithError(err).Warn("closing internal API manager")
			}
		}()
	}

	// Configure organization name resolver for metrics tagging.
	// This must be called once before registering tools that emit metrics.
	tools.ConfigureMetrics(provider)

	organizations.Register(srv, provider)
	projects.Register(srv, provider)
	workflows.Register(srv, provider)
	pipelines.Register(srv, provider)
	jobs.Register(srv, provider)
	docs.Register(srv)

	mux := http.NewServeMux()
	streamable := server.NewStreamableHTTPServer(
		srv,
		server.WithStreamableHTTPServer(&http.Server{
			Handler:           mux,
			ReadHeaderTimeout: 10 * time.Second,
		}),
		server.WithLogger(logging.NewStreamableLogger()),
	)

	streamableHandler := instrumentStreamableHandler(streamable)

	mux.Handle("/mcp", streamableHandler)
	mux.Handle("/mcp/", streamableHandler)

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

	logging.ForComponent("http").
		WithField("addr", *httpAddr).
		Info("streamable HTTP listener started")

	select {
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			logging.ForComponent("streamable_http").
				WithError(err).
				Fatal("streamable HTTP server failed")
		}
	case <-ctx.Done():
		healthy.Store(false)
		logging.ForComponent("http").Info("shutdown signal received, draining connections")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := streamable.Shutdown(shutdownCtx); err != nil && !errors.Is(err, context.Canceled) {
			logging.ForComponent("streamable_http").
				WithError(err).
				Error("graceful shutdown encountered an error")
		}

		if err := <-errCh; err != nil && !errors.Is(err, http.ErrServerClosed) {
			logging.ForComponent("streamable_http").
				WithError(err).
				Error("streamable HTTP server closed with error")
		}
	}
}

func configureHooks(hooks *server.Hooks) {
	if hooks == nil {
		return
	}

	hooks.AddOnRegisterSession(func(ctx context.Context, session server.ClientSession) {
		logging.ForComponent("session").
			WithField("sessionId", session.SessionID()).
			Info("session registered")
	})

	hooks.AddOnUnregisterSession(func(ctx context.Context, session server.ClientSession) {
		logging.ForComponent("session").
			WithField("sessionId", session.SessionID()).
			Info("session unregistered")
	})

	hooks.AddBeforeCallTool(func(ctx context.Context, id any, request *mcp.CallToolRequest) {
		toolLogger(ctx, id, request.Params.Name).
			WithField("arguments", request.Params.Arguments).
			Info("tool call started")
	})

	hooks.AddAfterCallTool(func(ctx context.Context, id any, request *mcp.CallToolRequest, result *mcp.CallToolResult) {
		entry := toolLogger(ctx, id, request.Params.Name)
		if result == nil {
			entry.Warn("tool call completed without a result payload")
			return
		}
		if result.IsError {
			errorMessage := extractErrorMessage(result)
			if errorMessage != "" {
				entry = entry.WithField("errorMessage", errorMessage)
			}
			entry.Warn("tool call completed with an error result")
			return
		}
		entry.Info("tool call completed successfully")
	})

	hooks.AddOnError(func(ctx context.Context, id any, method mcp.MCPMethod, message any, err error) {
		if method != mcp.MethodToolsCall {
			return
		}
		toolName := ""
		if req, ok := message.(*mcp.CallToolRequest); ok && req != nil {
			toolName = req.Params.Name
		}
		toolLogger(ctx, id, toolName).
			WithError(err).
			Error("tool call failed")
	})
}

func toolLogger(ctx context.Context, id any, toolName string) *logrus.Entry {
	fields := logrus.Fields{
		"tool": toolName,
	}
	if rid := requestIDString(id); rid != "" {
		fields["requestId"] = rid
	}
	if sid := sessionIDFromContext(ctx); sid != "" {
		fields["sessionId"] = sid
	}
	return logging.ForComponent("tool").WithFields(fields)
}

func sessionIDFromContext(ctx context.Context) string {
	if session := server.ClientSessionFromContext(ctx); session != nil {
		return session.SessionID()
	}
	return ""
}

func requestIDString(id any) string {
	if id == nil {
		return ""
	}
	return fmt.Sprint(id)
}

func extractErrorMessage(result *mcp.CallToolResult) string {
	if result == nil {
		return ""
	}
	for _, content := range result.Content {
		if text, ok := content.(mcp.TextContent); ok {
			value := strings.TrimSpace(text.Text)
			if value != "" {
				return value
			}
		}
	}
	if structured, ok := result.StructuredContent.(map[string]any); ok {
		if msg, found := structured["message"]; found {
			return fmt.Sprint(msg)
		}
		if errField, found := structured["error"]; found {
			return fmt.Sprint(errField)
		}
	}
	if str, ok := result.StructuredContent.(string); ok {
		value := strings.TrimSpace(str)
		if value != "" {
			return value
		}
	}
	return ""
}

func instrumentStreamableHandler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if next == nil {
			return
		}

		if r.Method == http.MethodGet || r.Method == http.MethodPost {
			entry := logging.ForComponent("http").
				WithFields(logrus.Fields{
					"method":     r.Method,
					"path":       r.URL.Path,
					"remoteAddr": r.RemoteAddr,
				})
			if r.Method == http.MethodGet {
				entry.Info("streamable connection opened")
			} else {
				entry.Info("streamable request received")
			}
		}

		next.ServeHTTP(w, r)
	})
}

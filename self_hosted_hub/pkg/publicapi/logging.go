package publicapi

import (
	"net/http"
	"time"

	log "github.com/sirupsen/logrus"
)

func loggingMiddleware(handler http.Handler, logger *log.Logger) http.Handler {
	return &loggingHandler{handler: handler, l: logger}
}

type loggingHandler struct {
	handler http.Handler
	l       *log.Logger
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (lh *loggingHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	start := time.Now()

	// Wrap the response writer to capture status code
	wrapped := &responseWriter{
		ResponseWriter: w,
		statusCode:     200, // default status code
	}

	lh.handler.ServeHTTP(wrapped, r)

	duration := time.Since(start)
	logFields := log.Fields{
		"method":     r.Method,
		"path":       r.URL.Path,
		"remote":     r.RemoteAddr,
		"user_agent": r.UserAgent(),
		"duration":   duration,
		"status":     wrapped.statusCode,
	}

	if wrapped.statusCode > 400 {
		lh.l.WithFields(logFields).Error("handled request")
	} else {
		lh.l.WithFields(logFields).Debug("handled request")
	}
}

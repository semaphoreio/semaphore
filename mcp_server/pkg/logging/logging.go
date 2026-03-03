package logging

import (
	"os"
	"strings"

	"github.com/mark3labs/mcp-go/util"
	"github.com/sirupsen/logrus"
)

var (
	baseLogger = logrus.New()
)

func init() {
	baseLogger.SetOutput(os.Stdout)
	baseLogger.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: "2006-01-02T15:04:05Z07:00",
	})

	level := strings.TrimSpace(os.Getenv("MCP_SERVER_LOG_LEVEL"))
	if level == "" {
		level = "info"
	}

	parsed, err := logrus.ParseLevel(level)
	if err != nil {
		baseLogger.SetLevel(logrus.InfoLevel)
		baseLogger.WithField("invalidLevel", level).
			Warn("unsupported MCP_SERVER_LOG_LEVEL, defaulting to info")
		return
	}
	baseLogger.SetLevel(parsed)
}

// Logger exposes the configured logrus.Logger instance.
func Logger() *logrus.Logger {
	return baseLogger
}

// ForComponent returns an entry bound to a component field.
func ForComponent(component string) *logrus.Entry {
	return baseLogger.WithField("component", component)
}

type streamableLogger struct {
	entry *logrus.Entry
}

// NewStreamableLogger creates a util.Logger backed by logrus for the streamable HTTP server.
func NewStreamableLogger() util.Logger {
	return &streamableLogger{entry: ForComponent("streamable_http")}
}

func (l *streamableLogger) Infof(format string, v ...any) {
	l.entry.Infof(format, v...)
}

func (l *streamableLogger) Errorf(format string, v ...any) {
	l.entry.Errorf(format, v...)
}

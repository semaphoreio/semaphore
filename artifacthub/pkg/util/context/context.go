package context

import (
	"context"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	"go.uber.org/zap"
)

type key int

const (
	logKey key = iota
	cleanupKey
)

const (
	bucketNameKey = "bucketName"
)

// SetBucketName adds logger to the context with bucket name tagged into it.
func SetBucketName(ctx context.Context, bucketName string) (context.Context, log.Logger) {
	return setLogger(ctx, zap.String(bucketNameKey, bucketName))
}

// setLogger returns a new logger with the given fields tagged to the logger, and the
// context containing this logger.
func setLogger(ctx context.Context, fields ...zap.Field) (context.Context, log.Logger) {
	l := log.With(fields...)
	return context.WithValue(ctx, logKey, l), l
}

// Logger returns a logger related to the given context.
func Logger(ctx context.Context) log.Logger {
	if ctx == nil {
		return log.Default
	}

	if ctxLogger, ok := ctx.Value(logKey).(log.Logger); ok {
		return ctxLogger
	}
	return log.Default
}

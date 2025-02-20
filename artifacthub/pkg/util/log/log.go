package log

import (
	"fmt"
	"os"
	"strings"

	"github.com/blendle/zapdriver"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const (
	keyVerbose = "VERBOSE"
	keyConsole = "CONSOLE"
)

// Default is the global logger.
var Default Logger

// PositiveEnv is returning true if the environment variable with the given key
// is positive, eg. any of [1, true, ok, on] with any case.
func PositiveEnv(key string) bool {
	val := strings.ToLower(os.Getenv(key))
	switch val {
	case "1", "true", "ok", "on":
		return true
	default:
		return false
	}
}

func init() {
	if strings.HasSuffix(os.Args[0], ".test") { // testing
		Default = Logger{zap.NewNop()}
	} else {
		var err error
		var zl *zap.Logger
		if PositiveEnv(keyConsole) {
			if PositiveEnv(keyVerbose) {
				zl, err = zap.NewDevelopment()
			} else {
				zl, err = zap.NewProduction()
			}
		} else {
			if ll := os.Getenv("LOG_LEVEL"); ll == "" || ll == "DEBUG" {
				zl, err = zapdriver.NewDevelopment()
			} else if ll == "INFO" {
				zl, err = zapdriver.NewProduction()
			} else {
				err = fmt.Errorf("LOG_LEVEL must be ['DEBUG', 'INFO'] or empty")
			}
		}
		if err != nil {
			panic(fmt.Errorf("failed to initialize logger: %s", err.Error()))
		}
		Default = Logger{zl}
	}
}

// Logger is a wrapper for zap logger that may have custom functions on it.
type Logger struct {
	*zap.Logger
}

func (l Logger) log(code codes.Code, msg string, err error,
	f func(msg string, fields ...zap.Field), fields ...zap.Field) error {
	if err == nil {
		err = status.Error(code, msg)
	} else {
		err = status.Errorf(code, msg+": %s", err.Error())
	}
	if len(fields) > 0 {
		newFields := make([]zap.Field, len(fields)+1)
		newFields[0] = zap.Error(err)
		copy(newFields[1:], fields)
		f(msg, fields...)
	} else {
		f(msg, zap.Stringer("code", code), zap.Error(err))
	}
	return err
}

// ErrorCode creates an error, and logs it.
func (l Logger) ErrorCode(code codes.Code, msg string, err error, fields ...zap.Field) error {
	return l.log(code, msg, err, l.Error, fields...)
}

// WarnCode creates an error, and logs it.
func (l Logger) WarnCode(code codes.Code, msg string, err error, fields ...zap.Field) error {
	return l.log(code, msg, err, l.Warn, fields...)
}

// ErrorCode creates an error, and logs it.
func ErrorCode(code codes.Code, msg string, err error, fields ...zap.Field) error {
	return Default.log(code, msg, err, Default.Error, fields...)
}

// WarnCode creates an error, and logs it.
func WarnCode(code codes.Code, msg string, err error, fields ...zap.Field) error {
	return Default.log(code, msg, err, Default.Warn, fields...)
}

// Debug writes a debug log message with the global logger.
func Debug(msg string, fields ...zap.Field) {
	Default.Debug(msg, fields...)
}

// Info writes an info log message with the global logger.
func Info(msg string, fields ...zap.Field) {
	Default.Info(msg, fields...)
}

// Warn writes a warning log message with the global logger.
func Warn(msg string, fields ...zap.Field) {
	Default.Warn(msg, fields...)
}

// Error writes an error log message with the global logger.
func Error(msg string, fields ...zap.Field) {
	Default.Error(msg, fields...)
}

// With creates a child logger and adds structured context to it. Fields added
// to the child don't affect the parent, and vice versa.
func With(fields ...zap.Field) Logger {
	return Logger{Default.With(fields...)}
}

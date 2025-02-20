package retry

import (
	"context"
	"time"

	ctxutil "github.com/semaphoreio/semaphore/artifacthub/pkg/util/context"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
)

var ( // TODO: these constants may be moved to conf or console arg
	// Limit is a number how many times bucket creation is retried before returning an error.
	Limit = 10
	// SoftLimit is similar but with smaller number for adequate functionality.
	SoftLimit = 2
	// StartTimeout is the starting timeout for requests in milliseconds.
	StartTimeout = time.Duration(1000)
	// AddTimeout is the the amount, that is added to timeout for each retry.
	AddTimeout = time.Duration(500)
)

// OnFailure calls the given function for a certain (RetryLimit) number of times. The
// function should be an inline function, so it can set return values. The function returns an
// error. The retries stop, if the error is nil. After the certain number of times expired, it
// returns the error anyway.
func OnFailure(ctx context.Context, msg string, toRun func() error) (err error) {
	timeout := StartTimeout
	for i := 0; i < Limit; i++ {
		err = toRun()
		if err == nil {
			return
		}
		if i == 0 {
			l := ctxutil.Logger(ctx)
			_ = l.WarnCode(codes.Unavailable, msg, err)
		}
		time.Sleep(timeout * time.Millisecond)
		timeout += AddTimeout
	}
	l := ctxutil.Logger(ctx)
	_ = l.ErrorCode(codes.Aborted, msg, err, zap.Int("retry number", Limit))
	return
}

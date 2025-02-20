package random

import (
	"context"
	"math/rand"
	"time"

	ctxutil "github.com/semaphoreio/semaphore/artifacthub/pkg/util/context"
	"google.golang.org/grpc/codes"
)

const (
	RandomLength     = 30
	letterBytesStart = "abcdefghijklmnopqrstuvwxyz"
	letterBytesEnd   = letterBytesStart + "0123456789"
	letterBytesMid   = letterBytesEnd + "-"
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

// randomName generates a name for the Service Account and the Bucket as well.
func randomName(ctx context.Context) ([]byte, error) {
	output := make([]byte, RandomLength)
	randomness := make([]byte, RandomLength)

	// generate some random bytes, this shouldn't fail
	// #nosec
	_, err := rand.Read(randomness)
	if err != nil {
		// if this fails, there's something very bad going on
		l := ctxutil.Logger(ctx)
		return nil, l.ErrorCode(codes.Internal, "Random number generation failed", err)
	}

	// fill output, starting character:
	l := uint8(len(letterBytesStart))
	random := uint8(randomness[0])          // get random item
	randomPos := random % l                 // random % length
	output[0] = letterBytesStart[randomPos] // put into output

	// fill output, middle characters:
	l = uint8(len(letterBytesMid))
	lastIndex := RandomLength - 1
	for pos := 1; pos < lastIndex; pos++ {
		random = uint8(randomness[pos])         // get random item
		randomPos = random % uint8(l)           // random % length
		output[pos] = letterBytesMid[randomPos] // put into output
	}
	// fill output, ending character:
	l = uint8(len(letterBytesEnd))
	random = uint8(randomness[lastIndex])         // get random item
	randomPos = random % l                        // random % length
	output[lastIndex] = letterBytesEnd[randomPos] // put into output

	return output, nil
}

// RandomNameStr returns a randomly generated string name, good for bucket and service account names.
func RandomNameStr(ctx context.Context) (string, error) {
	b, err := randomName(ctx)
	if err != nil {
		return "", err
	}
	return string(b), err
}

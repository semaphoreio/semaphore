package random

import (
	"context"
	"runtime/debug"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRandomName(t *testing.T) {
	ctx := context.Background()
	for i := 0; i < 20; i++ {
		r, err := randomName(ctx)
		assert.NoError(t, err)
		assert.Len(t, r, RandomLength, "random name length")

		assertInsideByteSet(t, "random name start", r[0], letterBytesStart)
		maxIndex := RandomLength - 1
		for j := 1; j < maxIndex; j++ {
			assertInsideByteSet(t, "random name mid", r[j], letterBytesMid)
		}

		assertInsideByteSet(t, "random name end", r[maxIndex], letterBytesEnd)
	}
}

func assertInsideByteSet(t *testing.T, msg string, b byte, set string) {
	for _, x := range []byte(set) {
		if x == b {
			return
		}
	}
	t.Fatalf(msg+" %c should be one of %s, but it's not; stack: %s", b, set, string(debug.Stack()))
}

package compression

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"errors"
	"io"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func Test_GzipDecompressBigFile(t *testing.T) {
	var b bytes.Buffer
	gz := gzip.NewWriter(&b)
	_, err := gz.Write([]byte(`{"key": "value"}`))
	if err != nil {
		t.Fatal(err)
	}
	err = gz.Close()
	if err != nil {
		t.Fatal(err)
	}

	reader := bytes.NewBuffer(b.Bytes())
	decompressedReader, err := GzipDecompress(reader, 15)
	if err != nil {
		t.Fatal(err)
	}
	decoder := json.NewDecoder(decompressedReader)
	err = decoder.Decode(&struct{}{})
	assert.Error(t, err, "should not be nil")
}

type erroringReader struct {
	err error
}

func (r *erroringReader) Read(p []byte) (int, error) {
	return 0, r.err
}

func Test_LimitedGzipReaderPropagatesReaderErrors(t *testing.T) {
	readErr := errors.New("connection reset by peer")
	lgr := NewLimitedGzipReader(&erroringReader{err: readErr}, 100, nil)

	n, err := lgr.Read(make([]byte, 10))

	assert.Equal(t, 0, n)
	assert.ErrorIs(t, err, readErr)
}

func Test_GzipDecompressTruncatedStreamReturnsError(t *testing.T) {
	var b bytes.Buffer
	gz := gzip.NewWriter(&b)
	_, err := gz.Write(bytes.Repeat([]byte(`{"key": "value"}`), 1000))
	if err != nil {
		t.Fatal(err)
	}
	err = gz.Close()
	if err != nil {
		t.Fatal(err)
	}

	truncated := b.Bytes()[:b.Len()/2]
	reader, err := GzipDecompress(bytes.NewReader(truncated), 1024*1024)
	if err != nil {
		t.Fatal(err)
	}

	done := make(chan error, 1)
	go func() {
		_, readErr := io.ReadAll(reader)
		done <- readErr
	}()

	select {
	case readErr := <-done:
		assert.Error(t, readErr)
	case <-time.After(5 * time.Second):
		t.Fatal("read of truncated gzip stream did not terminate")
	}
}

package storage

import (
	"bytes"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"runtime"
	"testing"
	"time"

	assert "github.com/stretchr/testify/assert"
)

func Test__GzippedDataCanBeReadWithGunzip(t *testing.T) {
	data := []byte("Testing compression")
	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write(data)

	err := Gzip(context.Background(), tempFile.Name())
	assert.Nil(t, err)

	compressedFile, _ := ioutil.ReadFile(fmt.Sprintf("%s.gz", tempFile.Name()))
	decompressed, err := Gunzip(compressedFile)
	assert.Nil(t, err)

	assert.Equal(t, string(decompressed), string(data))
	os.Remove(tempFile.Name())
}

func Test__GzipRemovesOriginalFile(t *testing.T) {
	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write([]byte("some logs"))
	tempFile.Close()
	defer os.Remove(tempFile.Name() + ".gz")

	err := Gzip(context.Background(), tempFile.Name())
	assert.Nil(t, err)

	_, err = os.Stat(tempFile.Name())
	assert.True(t, os.IsNotExist(err))

	_, err = os.Stat(tempFile.Name() + ".gz")
	assert.Nil(t, err)
}

func Test__GzipFailsForMissingFile(t *testing.T) {
	fileName := fmt.Sprintf("%s/does-not-exist-%d", os.TempDir(), os.Getpid())

	err := Gzip(context.Background(), fileName)
	assert.NotNil(t, err)

	_, err = os.Stat(fileName + ".gz")
	assert.True(t, os.IsNotExist(err))
}

func Test__GzipDoesNotOverwriteExistingArchive(t *testing.T) {
	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write([]byte("some logs"))
	tempFile.Close()
	defer os.Remove(tempFile.Name())

	existing := tempFile.Name() + ".gz"
	assert.Nil(t, ioutil.WriteFile(existing, []byte("existing"), 0600))
	defer os.Remove(existing)

	err := Gzip(context.Background(), tempFile.Name())
	assert.NotNil(t, err)

	// original input and pre-existing archive are both left untouched
	_, err = os.Stat(tempFile.Name())
	assert.Nil(t, err)
	content, _ := ioutil.ReadFile(existing)
	assert.Equal(t, "existing", string(content))
}

func Test__GzipFailsForCancelledContext(t *testing.T) {
	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write([]byte("some logs"))
	tempFile.Close()
	defer os.Remove(tempFile.Name())

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	err := Gzip(ctx, tempFile.Name())
	assert.NotNil(t, err)

	_, err = os.Stat(tempFile.Name())
	assert.Nil(t, err)
}

func Test__GzipSucceedsAndKeepsArchiveWhenRemovingOriginalFails(t *testing.T) {
	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write([]byte("some logs"))
	tempFile.Close()
	defer os.Remove(tempFile.Name())
	defer os.Remove(tempFile.Name() + ".gz")

	unlinkErr := fmt.Errorf("unlink failed")
	originalRemove := removeFile
	removeFile = func(name string) error {
		if name == tempFile.Name() {
			return unlinkErr
		}
		return os.Remove(name)
	}
	defer func() { removeFile = originalRemove }()

	err := Gzip(context.Background(), tempFile.Name())
	assert.Nil(t, err)

	// the complete archive survives and is readable
	compressedFile, err := ioutil.ReadFile(tempFile.Name() + ".gz")
	assert.Nil(t, err)
	decompressed, err := Gunzip(compressedFile)
	assert.Nil(t, err)
	assert.Equal(t, "some logs", string(decompressed))

	// the original is still there too
	_, err = os.Stat(tempFile.Name())
	assert.Nil(t, err)
}

func Test__GzipStopsWhenContextIsCancelledDuringCompression(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	reader := &contextReader{ctx: ctx, r: bytes.NewReader([]byte("some logs"))}

	buf := make([]byte, 4)
	n, err := reader.Read(buf)
	assert.Nil(t, err)
	assert.Equal(t, 4, n)

	cancel()

	n, err = reader.Read(buf)
	assert.Equal(t, context.Canceled, err)
	assert.Equal(t, 0, n)
}

func Test__GzipLargeInputRoundTripsWithStdlibAndPgzip(t *testing.T) {
	// several MB of non-trivial data, so compression spans multiple blocks
	var buf bytes.Buffer
	for i := 0; buf.Len() < 5<<20; i++ {
		fmt.Fprintf(&buf, "line %d: some log output %d\n", i, i*7919%104729)
	}

	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write(buf.Bytes())
	tempFile.Close()
	defer os.Remove(tempFile.Name() + ".gz")

	assert.Nil(t, Gzip(context.Background(), tempFile.Name()))

	compressed, err := ioutil.ReadFile(tempFile.Name() + ".gz")
	assert.Nil(t, err)

	viaPgzip, err := Gunzip(compressed)
	assert.Nil(t, err)
	assert.True(t, bytes.Equal(buf.Bytes(), viaPgzip))

	stdReader, err := gzip.NewReader(bytes.NewReader(compressed))
	assert.Nil(t, err)
	viaStdlib, err := io.ReadAll(stdReader)
	assert.Nil(t, err)
	assert.True(t, bytes.Equal(buf.Bytes(), viaStdlib))
}

type failingWriter struct{ after int }

func (f *failingWriter) Write(p []byte) (int, error) {
	if f.after <= 0 {
		return 0, fmt.Errorf("no space left on device")
	}
	f.after -= len(p)
	return len(p), nil
}

type endlessReader struct{ ctx context.Context }

func (e *endlessReader) Read(p []byte) (int, error) {
	for i := range p {
		p[i] = byte(i * 31)
	}
	return len(p), nil
}

func settledGoroutines() int {
	var n int
	for i := 0; i < 20; i++ {
		runtime.GC()
		time.Sleep(50 * time.Millisecond)
		n = runtime.NumGoroutine()
	}
	return n
}

func Test__GzipStreamDoesNotLeakGoroutinesOnFailure(t *testing.T) {
	before := settledGoroutines()

	for i := 0; i < 30; i++ {
		// write failure, e.g. full disk
		err := gzipStream(&failingWriter{after: 1 << 10}, &endlessReader{})
		assert.NotNil(t, err)

		// cancelled mid-copy
		ctx, cancel := context.WithCancel(context.Background())
		reader := &contextReader{ctx: ctx, r: &endlessReader{}}
		go func() { time.Sleep(5 * time.Millisecond); cancel() }()
		err = gzipStream(io.Discard, reader)
		assert.Equal(t, context.Canceled, err)
	}

	after := settledGoroutines()
	assert.LessOrEqual(t, after, before+2, "goroutines grew from %d to %d", before, after)
}

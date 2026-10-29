package storage

import (
	"bufio"
	"bytes"
	"context"
	"compress/gzip"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"

	pgzip "github.com/klauspost/pgzip"

	"github.com/renderedtext/go-watchman"
)

// removeFile is swapped in tests to simulate unlink failures.
var removeFile = os.Remove

// Gzip compresses fileName into fileName.gz and removes the original,
// matching the behavior of the gzip command line tool. A partially written
// archive is removed on failure. Once the archive is complete it is kept and
// Gzip succeeds, even if removing the original fails: that error is only
// logged, since failing here would leave both files behind for nothing.
func Gzip(ctx context.Context, fileName string) error {
	defer watchman.Benchmark(time.Now(), "logs.compress")

	if err := ctx.Err(); err != nil {
		return err
	}

	if err := compressFile(ctx, fileName, fileName+".gz"); err != nil {
		return err
	}

	if err := removeFile(fileName); err != nil {
		log.Printf("Failed to remove %s after compressing it: %v", filepath.Base(fileName), err)
	}

	return nil
}

func compressFile(ctx context.Context, srcName, dstName string) (err error) {
	src, err := os.Open(filepath.Clean(srcName))
	if err != nil {
		return err
	}
	defer src.Close()

	dst, err := os.OpenFile(filepath.Clean(dstName), os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}

	defer func() {
		if err != nil {
			_ = dst.Close()
			_ = removeFile(dstName)
		}
	}()

	writer := gzip.NewWriter(dst)
	if _, err = io.Copy(writer, &contextReader{ctx: ctx, r: src}); err != nil {
		return err
	}

	if err = writer.Close(); err != nil {
		return err
	}

	return dst.Close()
}

// contextReader stops reading once ctx is done, so a cancelled or timed
// out context aborts an in-progress compression.
type contextReader struct {
	ctx context.Context
	r   io.Reader
}

func (c *contextReader) Read(p []byte) (int, error) {
	if err := c.ctx.Err(); err != nil {
		return 0, err
	}

	return c.r.Read(p)
}

func Gunzip(data []byte) ([]byte, error) {
	defer watchman.Benchmark(time.Now(), "logs.decompress")

	buffer := bytes.NewBuffer(data)
	reader, err := pgzip.NewReader(buffer)
	if err != nil {
		return nil, err
	}

	result, err := io.ReadAll(reader)
	if err != nil {
		return nil, err
	}

	return result, nil
}

func GunzipWithReader(zippedReader io.Reader, processFn func([]byte) error) error {
	rawReader, err := pgzip.NewReader(zippedReader)
	if err != nil {
		return err
	}

	bufferedReader := bufio.NewReader(rawReader)

	for {
		line, err := bufferedReader.ReadBytes('\n')
		if err == io.EOF {
			break
		}

		if err != nil {
			return err
		}

		err = processFn(line)
		if err != nil {
			return err
		}
	}

	return nil
}

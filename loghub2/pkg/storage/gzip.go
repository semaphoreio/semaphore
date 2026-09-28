package storage

import (
	"bufio"
	"bytes"
	"compress/gzip"
	"context"
	"io"
	"os"
	"path/filepath"
	"time"

	pgzip "github.com/klauspost/pgzip"

	"github.com/renderedtext/go-watchman"
)

// Gzip compresses fileName into fileName.gz and removes the original,
// matching the behavior of the gzip command line tool.
func Gzip(ctx context.Context, fileName string) (err error) {
	defer watchman.Benchmark(time.Now(), "logs.compress")

	if err := ctx.Err(); err != nil {
		return err
	}

	src, err := os.Open(filepath.Clean(fileName))
	if err != nil {
		return err
	}
	defer src.Close()

	gzippedFileName := filepath.Clean(fileName + ".gz")
	dst, err := os.OpenFile(gzippedFileName, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}

	defer func() {
		if err != nil {
			_ = dst.Close()
			_ = os.Remove(gzippedFileName)
		}
	}()

	writer := gzip.NewWriter(dst)
	if _, err = io.Copy(writer, src); err != nil {
		return err
	}

	if err = writer.Close(); err != nil {
		return err
	}

	if err = dst.Close(); err != nil {
		return err
	}

	return os.Remove(fileName)
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

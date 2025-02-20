package storage

import (
	"bufio"
	"bytes"
	"context"
	"io"
	"os/exec"
	"time"

	pgzip "github.com/klauspost/pgzip"

	"github.com/renderedtext/go-watchman"
)

func Gzip(ctx context.Context, fileName string) error {
	defer watchman.Benchmark(time.Now(), "logs.compress")

	cmd := exec.CommandContext(ctx, "gzip", fileName)
	_, err := cmd.Output()
	if err != nil {
		return err
	}

	return nil
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

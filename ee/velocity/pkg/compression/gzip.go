// Package compression holds the compression utilities.
package compression

import (
	"bytes"
	"compress/gzip"
	"errors"
	"io"
	"log"
)

type LimitedGzipReader struct {
	Reader    io.Reader
	MaxSize   int64
	Count     int64
	CloseFunc func() error
}

var ErrSizeLimitReached = errors.New("size limit reached")

func GzipDecompress(reader io.Reader, maxSize int64) (io.Reader, error) {
	isCompressed, reader, err := IsGzipCompressed(reader)
	if err != nil {
		return nil, err
	}

	if !isCompressed {
		return NewLimitedGzipReader(reader, maxSize, nil), nil
	}

	gzReader, err := gzip.NewReader(reader)
	if err != nil {
		log.Printf("Decompression failed: %v", err)
		return nil, err
	}

	return NewLimitedGzipReader(gzReader, maxSize, gzReader.Close), nil
}

func NewLimitedGzipReader(reader io.Reader, maxSize int64, closeFunc func() error) *LimitedGzipReader {
	return &LimitedGzipReader{
		Reader:    reader,
		MaxSize:   maxSize,
		CloseFunc: closeFunc,
	}
}

func IsGzipCompressed(reader io.Reader) (bool, io.Reader, error) {
	header := make([]byte, 2)
	n, err := reader.Read(header)
	if err != nil {
		return false, reader, err
	}
	if n < 2 {
		return false, reader, errors.New("could not read enough data for GZIP header")
	}

	// Check if the header matches GZIP magic numbers
	isCompressed := header[0] == 0x1f && header[1] == 0x8b

	// Combine the read bytes with the original reader
	reader = io.MultiReader(bytes.NewReader(header), reader)

	return isCompressed, reader, nil
}

func (lgr *LimitedGzipReader) Read(p []byte) (int, error) {
	if lgr.Count >= lgr.MaxSize {
		return 0, ErrSizeLimitReached
	}

	n, err := lgr.Reader.Read(p)
	lgr.Count += int64(n)
	if lgr.Count > lgr.MaxSize {
		return 0, ErrSizeLimitReached
	}
	if err == io.EOF && lgr.Count < lgr.MaxSize {
		// Return EOF only if it's a natural end, not due to size limit
		return n, err
	}
	if lgr.Count >= lgr.MaxSize {
		// Size limit reached, return custom error
		return n, ErrSizeLimitReached
	}
	return n, nil
}

func (lgr *LimitedGzipReader) Close() error {
	if lgr.CloseFunc != nil {
		return lgr.CloseFunc()
	}
	return nil
}

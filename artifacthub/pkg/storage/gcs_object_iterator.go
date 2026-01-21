package storage

import (
	"errors"
	"time"

	gcsstorage "cloud.google.com/go/storage"
	"google.golang.org/api/iterator"
)

type GcsPathIterator struct {
	iterator *gcsstorage.ObjectIterator
	isDone   bool
}

var _ PathIterator = &GcsPathIterator{}

func (i *GcsPathIterator) Next() (*PathItem, error) {
	attrs, err := i.iterator.Next()

	if err != nil {
		if err == iterator.Done {
			i.isDone = true
			return nil, ErrNoMoreObjects
		}

		if errors.Is(err, gcsstorage.ErrBucketNotExist) {
			i.isDone = true
			return nil, ErrMissingBucket
		}

		return nil, err
	}

	// If prefix is set, this is a directory.
	// This will only happen if storage.ListOptions.WrapSubDirectories is set.
	if attrs.Prefix != "" {
		return &PathItem{
			Path:        attrs.Prefix,
			IsDirectory: true,
			Age:         nil,
			Size:        0, // Directories don't have a size
		}, nil
	}

	age := time.Since(attrs.Created)
	return &PathItem{
		Path:        attrs.Name,
		IsDirectory: false,
		Age:         &age,
		Size:        attrs.Size,
	}, nil
}

func (i *GcsPathIterator) Count() (int, error) {
	count := 0

	for !i.Done() {
		_, err := i.Next()
		if err == ErrNoMoreObjects {
			break
		}

		if err != nil {
			return count, err
		}

		count++
	}

	return count, nil
}

func (i *GcsPathIterator) Done() bool {
	return i.isDone
}

package storage

import (
	"context"
	"fmt"
	"time"
)

type Client interface {
	GetBucket(options BucketOptions) Bucket
	CreateBucket(ctx context.Context) (string, error)
	DestroyBucket(ctx context.Context, options BucketOptions) error
	SignURL(ctx context.Context, options SignURLOptions) (string, error)
}

type BucketOptions struct {
	Name       string
	PathPrefix string
}

type SignURLOptions struct {
	BucketName         string
	Path               string
	Method             string
	PathPrefix         string
	IncludeContentType bool
}

type Bucket interface {
	ListPath(options ListOptions) (PathIterator, error)
	ListObjectsWithPagination(options ListOptions) (ObjectPager, error)
	DeleteObjects(paths []string) error
	CreateObject(ctx context.Context, objectName string, content []byte) error
	IsDir(ctx context.Context, path string) (bool, error)
	IsFile(ctx context.Context, path string) (bool, error)
	DeletePath(ctx context.Context, path string) error
	DeleteDir(ctx context.Context, path string) error
	DeleteFile(ctx context.Context, path string) error
	SetCORS(ctx context.Context) error
	Destroy(ctx context.Context) error
}

type ListOptions struct {
	Path               string
	MaxKeys            int64
	WrapSubDirectories bool
	PaginationToken    string
}

func (o *ListOptions) UseDelimiter() bool {
	return o.WrapSubDirectories
}

type PathItem struct {
	Path        string
	IsDirectory bool
	Age         *time.Duration
	Size        int64
}

type PathIterator interface {
	Next() (*PathItem, error)
	Count() (int, error)
	Done() bool
}

type Object struct {
	Path string
	Age  *time.Duration
}

type ObjectPager interface {
	NextPage() ([]*Object, string, error)
}

var ErrNoMoreObjects = fmt.Errorf("no more objects in the storage")
var ErrMissingBucket = fmt.Errorf("storage: bucket doesn't exist")

package storage

import (
	"context"
	"fmt"
	"io"
	"strings"
	"time"

	gcsstorage "cloud.google.com/go/storage"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/parallel"
	ctxutil "github.com/semaphoreio/semaphore/artifacthub/pkg/util/context"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	pathutil "github.com/semaphoreio/semaphore/artifacthub/pkg/util/path"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/retry"
	"go.uber.org/zap"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const GcsStorageListObjectPageSize = 1000 // google cloud API docs' recomendation

type GcsBucket struct {
	BucketName    string
	BucketHandler *gcsstorage.BucketHandle
}

var _ Bucket = &GcsBucket{}

func (b *GcsBucket) Destroy(ctx context.Context) error {
	return retry.OnFailure(ctx, "Bucket deletion", func() error {
		return b.BucketHandler.Delete(ctx)
	})
}

// AddUser connects a bucket with a service account with the adequate role permission.
func (b *GcsBucket) AddUser(ctx context.Context, email string) error {
	return retry.OnFailure(ctx, "Service account and bucket connection", func() error {
		policy, err := b.BucketHandler.IAM().Policy(ctx)
		if err != nil {
			return fmt.Errorf("bucket.IAM().Policy: %s", err)
		}

		// https://cloud.google.com/storage/docs/access-control/iam
		policy.Add("serviceAccount:"+email, "roles/storage.objectAdmin")
		if err = b.BucketHandler.IAM().SetPolicy(ctx, policy); err != nil {
			return fmt.Errorf("bucket.IAM().SetPolicy: %s", err)
		}

		return nil
	})
}

// RemoveUser removes bucket-service account connection.
func (b *GcsBucket) RemoveUser(ctx context.Context, email string) error {
	return retry.OnFailure(ctx, "Service account and bucket detach", func() error {
		policy, err := b.BucketHandler.IAM().Policy(ctx)
		if err != nil {
			return fmt.Errorf("bucket.IAM().Policy: %s", err)
		}

		policy.Remove("serviceAccount:"+email, "roles/storage.objectAdmin")
		if err = b.BucketHandler.IAM().SetPolicy(ctx, policy); err != nil {
			return fmt.Errorf("bucket.IAM().SetPolicy: %s", err)
		}

		return nil
	})
}

func (b *GcsBucket) IsFile(ctx context.Context, path string) (bool, error) {
	if len(path) == 0 {
		return false, nil
	}

	o := b.BucketHandler.Object(path)
	_, err := o.Attrs(ctx)

	if err == nil {
		return true, nil
	}

	if err == gcsstorage.ErrObjectNotExist {
		return false, nil
	}

	l := ctxutil.Logger(ctx)
	return false, l.ErrorCode(codes.Unknown, "IsFile in GCS", err)
}

func (b *GcsBucket) IsDir(ctx context.Context, dir string) (bool, error) {
	if len(dir) == 0 {
		return true, nil
	}

	iterator, err := b.ListPath(ListOptions{Path: dir})
	if err != nil {
		return false, err
	}

	_, err = iterator.Next()

	// If the iterator returns no objects, the directory does not exist
	if err == ErrNoMoreObjects {
		return false, nil
	}

	// If the iterator returns an error, we assume false and return the error
	if err != nil {
		return false, err
	}

	// If the iterator does not return an error, there is at least one object
	// in the path specified, so the directory exists
	return true, nil
}

// DelPath deletes object or directory from a Google Cloud Storage bucket.
func (b *GcsBucket) DeletePath(ctx context.Context, name string) error {
	return retry.OnFailure(ctx, "Deleting Bucket path", func() error {
		isFile, err := b.IsFile(ctx, name)
		if err != nil {
			if err == gcsstorage.ErrBucketNotExist {
				return ErrMissingBucket
			}
			return err
		}

		if isFile {
			return b.DeleteFile(ctx, name)
		}

		err = b.DeleteDir(ctx, name)
		if err != nil {
			if err == gcsstorage.ErrBucketNotExist {
				return ErrMissingBucket
			}
		}
		return err
	})
}

func (b *GcsBucket) DeleteDir(ctx context.Context, dir string) error {
	iterator, err := b.ListPath(ListOptions{Path: dir})
	if err != nil {
		if err == gcsstorage.ErrBucketNotExist {
			return ErrMissingBucket
		}
		return err
	}

	for !iterator.Done() {
		object, err := iterator.Next()
		if err == ErrNoMoreObjects {
			break
		}

		if err != nil {
			if err == gcsstorage.ErrBucketNotExist {
				return ErrMissingBucket
			}
			return err
		}

		err = b.DeleteFile(ctx, object.Path)
		if err != nil {
			return err
		}
	}

	return nil
}

func (b *GcsBucket) DeleteFile(ctx context.Context, filename string) error {
	err := b.BucketHandler.Object(filename).Delete(ctx)

	if err != nil {
		l := ctxutil.Logger(ctx)
		if err == gcsstorage.ErrObjectNotExist {
			l.Debug("file already deleted in GCS", zap.String("filename", filename))
			return nil
		}
		return l.ErrorCode(codes.Unknown, "DelFile in GCS", err)
	}

	return nil
}

func (b *GcsBucket) SetCORS(ctx context.Context) error {
	if _, err := b.BucketHandler.Update(ctx, gcsstorage.BucketAttrsToUpdate{CORS: cors}); err != nil {
		log.Error("Failed to update bucket with CORS",
			zap.String("bucketName", b.BucketName), zap.Error(err))
		return status.Error(codes.Unavailable,
			"Failed to update bucket with CORS")
	}
	return nil
}

func (b *GcsBucket) CreatedAt(ctx context.Context, path string) (time.Time, error) {
	a, err := b.BucketHandler.Object(path).Attrs(ctx)
	if err != nil {
		return time.Time{}, err
	}
	return a.Created, nil
}

func (b *GcsBucket) DeleteObjects(paths []string) error {

	// GCS does not support deleting objects in bulk,
	// so we parallelize the deletion requests to make them faster.
	processor := parallel.NewParallelProcessor(paths, func(path string) {
		err := b.BucketHandler.Object(path).Delete(context.Background())
		if err != nil {
			log.Error("Failed to delete object", zap.String("object", path), zap.Error(err))
		}
	}, 10)

	processor.Run()
	return nil
}

func (b *GcsBucket) ListPath(options ListOptions) (PathIterator, error) {
	query := gcsstorage.Query{Prefix: pathutil.EndsInSlash(options.Path)}
	err := query.SetAttrSelection([]string{"Name", "Created", "Size"})
	if err != nil {
		return nil, err
	}

	if options.UseDelimiter() {
		query.Delimiter = "/"
	}

	iterator := b.BucketHandler.Objects(
		context.Background(),
		&query,
	)

	return &GcsPathIterator{iterator: iterator}, nil
}

func (b *GcsBucket) ListObjectsWithPagination(options ListOptions) (ObjectPager, error) {
	query := gcsstorage.Query{Prefix: pathutil.EndsInSlash(options.Path)}
	err := query.SetAttrSelection([]string{"Name", "Created", "Size"})
	if err != nil {
		return nil, err
	}

	i := b.BucketHandler.Objects(
		context.Background(),
		&query,
	)

	maxKeys := int(options.MaxKeys)
	if maxKeys == 0 {
		maxKeys = int(GcsStorageListObjectPageSize)
	}

	pager := iterator.NewPager(i, maxKeys, options.PaginationToken)
	return &GcsObjectPager{pager: pager}, nil
}

// Only used in tests
func (b *GcsBucket) CreateObject(ctx context.Context, objectName string, content []byte) error {
	writer := b.BucketHandler.Object(objectName).NewWriter(ctx)

	if _, err := io.Copy(writer, strings.NewReader(string(content))); err != nil {
		return fmt.Errorf("error uploading object %s: %v", objectName, err)
	}

	if err := writer.Close(); err != nil {
		return fmt.Errorf("error closing writer: %v", err)
	}

	return nil
}

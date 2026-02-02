package storage

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/service/s3"
	ctxutil "github.com/semaphoreio/semaphore/artifacthub/pkg/util/context"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	pathutil "github.com/semaphoreio/semaphore/artifacthub/pkg/util/path"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type S3Bucket struct {
	Client     *s3.S3
	BucketName string
	PathPrefix string
}

var _ Bucket = &S3Bucket{}

func (b *S3Bucket) prefixPath(path string) string {
	if b.PathPrefix != "" {
		return fmt.Sprintf("%s/%s", b.PathPrefix, path)
	}

	return path
}

// no-op for S3
func (b *S3Bucket) Destroy(ctx context.Context) error {
	return nil
}

func (b *S3Bucket) IsFile(ctx context.Context, path string) (bool, error) {
	if len(path) == 0 {
		return false, nil
	}

	prefixedPath := b.prefixPath(path)
	obj, err := b.Client.GetObjectWithContext(ctx, &s3.GetObjectInput{
		Bucket: aws.String(b.BucketName),
		Key:    aws.String(prefixedPath),
	})

	if err != nil {
		if aerr, ok := err.(awserr.Error); ok {
			if aerr.Code() == s3.ErrCodeNoSuchKey {
				return false, nil
			}
		}

		return false, err
	}
	err = obj.Body.Close()
	if err != nil {
		return false, err
	}
	return true, nil
}

func (b *S3Bucket) IsDir(ctx context.Context, path string) (bool, error) {
	if len(path) == 0 {
		return true, nil
	}

	iterator, err := b.ListPath(ListOptions{Path: path})

	if err != nil {
		return false, err
	}

	_, err = iterator.Next()
	if err == ErrNoMoreObjects {
		return false, nil
	}

	if err != nil {
		return false, err
	}

	return true, nil
}

func (b *S3Bucket) DeletePath(ctx context.Context, path string) error {
	isFile, err := b.IsFile(ctx, path)
	if err != nil {
		var aerr awserr.Error
		if errors.As(err, &aerr) && aerr.Code() == s3.ErrCodeNoSuchBucket {
			return ErrMissingBucket
		}
		return err
	}

	if isFile {
		return b.DeleteFile(ctx, path)
	}

	err = b.DeleteDir(ctx, path)
	if err != nil {
		var aerr awserr.Error
		if errors.As(err, &aerr) && aerr.Code() == s3.ErrCodeNoSuchBucket {
			return ErrMissingBucket
		}
	}
	return err
}

// When deleting a directory, we list all the files in that directory
// and delete all the listed files in 1000-object chunks using the S3 DeleteObjects operation.
func (b *S3Bucket) DeleteDir(ctx context.Context, path string) error {
	iterator, err := b.ListPath(ListOptions{Path: path})

	if err != nil {
		var aerr awserr.Error
		if errors.As(err, &aerr) && aerr.Code() == s3.ErrCodeNoSuchBucket {
			return ErrMissingBucket
		}
		return err
	}

	// Collect all the objects returned by the list iterator
	identifiers := []*s3.ObjectIdentifier{}
	for !iterator.Done() {
		object, err := iterator.Next()
		if err == ErrNoMoreObjects {
			break
		}

		if err != nil {
			var aerr awserr.Error
			if errors.As(err, &aerr) && aerr.Code() == s3.ErrCodeNoSuchBucket {
				return ErrMissingBucket
			}
			return err
		}

		identifiers = append(identifiers, &s3.ObjectIdentifier{
			Key: aws.String(b.prefixPath(object.Path)),
		})
	}

	// Nothing to delete, just return
	if len(identifiers) == 0 {
		return nil
	}

	// the s3 DeleteObjects operation only allows up to 1000 keys to be used
	// so we build 1000-object chunks
	chunks := b.createChunks(identifiers, 1000)

	// Delete chunk by chunk.
	// If there are any errors when deleting a chunk,
	// the operation comes to an end and we return that error
	for _, chunk := range chunks {
		err := b.deleteChunk(chunk)
		if err != nil {
			return err
		}
	}

	return nil
}

func (b *S3Bucket) deleteChunk(chunk []*s3.ObjectIdentifier) error {
	output, err := b.Client.DeleteObjects(&s3.DeleteObjectsInput{
		Bucket: aws.String(b.BucketName),
		Delete: &s3.Delete{
			Objects: chunk,
		},
	})

	if err != nil {
		return err
	}

	// No errors, all the objects were deleted
	if len(output.Errors) == 0 {
		return nil
	}

	// If there are any errors, we just return the first one
	return fmt.Errorf("error deleting objects: %v", *output.Errors[0].Message)
}

func (b *S3Bucket) createChunks(objects []*s3.ObjectIdentifier, chunkSize int) [][]*s3.ObjectIdentifier {
	var chunks [][]*s3.ObjectIdentifier
	for i := 0; i < len(objects); i += chunkSize {
		end := i + chunkSize

		if end > len(objects) {
			end = len(objects)
		}

		chunks = append(chunks, objects[i:end])
	}

	return chunks
}

func (b *S3Bucket) DeleteFile(ctx context.Context, path string) error {
	prefixedPath := b.prefixPath(path)

	_, err := b.Client.DeleteObjectWithContext(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(b.BucketName),
		Key:    aws.String(prefixedPath),
	})

	if err != nil {
		l := ctxutil.Logger(ctx)

		if aerr, ok := err.(awserr.Error); ok {
			if aerr.Code() == s3.ErrCodeNoSuchKey {
				l.Debug("file already deleted in S3", zap.String("filename", prefixedPath))
				return nil
			}
		}

		return l.ErrorCode(codes.Unknown, "DelFile in S3", err)
	}

	return nil
}

func (b *S3Bucket) SetCORS(ctx context.Context) error {
	_, err := b.Client.PutBucketCorsWithContext(ctx, &s3.PutBucketCorsInput{
		Bucket: aws.String(b.BucketName),
		CORSConfiguration: &s3.CORSConfiguration{
			CORSRules: []*s3.CORSRule{
				{
					MaxAgeSeconds:  aws.Int64(int64(time.Hour.Seconds())),
					ExposeHeaders:  aws.StringSlice([]string{"Access-Control-Request-Header"}),
					AllowedMethods: aws.StringSlice([]string{"GET", "HEAD"}),
					AllowedOrigins: aws.StringSlice(strings.Split(os.Getenv("CORS_ORIGINS"), ",")),
				},
			},
		},
	})

	if err != nil {
		log.Error("Failed to update bucket with CORS", zap.String("bucketName", b.BucketName), zap.Error(err))
		return status.Error(codes.Unavailable, "Failed to update bucket with CORS")
	}

	return nil
}

func (b *S3Bucket) DeleteObjects(paths []string) error {
	for i := 0; i < len(paths); i++ {
		err := b.DeletePath(context.Background(), paths[i])
		if err != nil {
			return err
		}
	}

	return nil
}

func (b *S3Bucket) ListPath(options ListOptions) (PathIterator, error) {
	path := b.prefixPath(pathutil.EndsInSlash(options.Path))
	input := s3.ListObjectsInput{
		Bucket: aws.String(b.BucketName),
		Prefix: aws.String(path),
	}

	if options.MaxKeys > 0 {
		input.MaxKeys = aws.Int64(options.MaxKeys)
	}

	if options.UseDelimiter() {
		input.Delimiter = aws.String("/")
	}

	output, err := b.Client.ListObjects(&input)

	if err != nil {
		var aerr awserr.Error
		if errors.As(err, &aerr) && aerr.Code() == s3.ErrCodeNoSuchBucket {
			return nil, ErrMissingBucket
		}
		return nil, err
	}

	return &S3PathIterator{
		Client:     b.Client,
		LastOutput: output,
		PathPrefix: b.PathPrefix,
	}, nil
}

func (b *S3Bucket) ListObjectsWithPagination(options ListOptions) (ObjectPager, error) {
	maxKeys := options.MaxKeys
	if maxKeys == 0 {
		maxKeys = 1000
	}

	return &S3ObjectPager{
		Client:     b.Client,
		BucketName: b.BucketName,
		PathPrefix: b.PathPrefix,
		Prefix:     b.prefixPath(pathutil.EndsInSlash(options.Path)),
		NextMarker: options.PaginationToken,
		MaxKeys:    maxKeys,
	}, nil
}

// Only used in tests
func (b *S3Bucket) CreateObject(ctx context.Context, objectName string, content []byte) error {
	path := b.prefixPath(objectName)
	_, err := b.Client.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(b.BucketName),
		Key:    aws.String(path),
		Body:   strings.NewReader(string(content)),
	})

	return err
}
